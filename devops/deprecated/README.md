# vaultwarden_backup

Helm chart project for deploying Vaultwarden on Kubernetes together with an automated backup workflow.

By default, all resources are intended to be created in the `vaultwarden` namespace.

## Overview

This repository is intended to manage:

- a Vaultwarden workload running from `docker.io/vaultwarden/server:latest`
- persistent application storage on a shared `PersistentVolumeClaim` sized at `5Gi`
- a single hourly Restic backup job that mounts the same PVC and snapshots the Vaultwarden data to remote storage

The current target design is:

1. A `StatefulSet` runs Vaultwarden and mounts the main data PVC.
2. A single backup `CronJob` runs every hour and mounts the same PVC at `/data`.
3. The backup job 
  - uses a dedicated Kubernetes service account with RBAC that can scale the Vaultwarden `StatefulSet` down to `0` and back to `1`.
  - stops Vaultwarden, runs Restic against the Vaultwarden data directory, applies retention with `restic forget --prune`, and then starts Vaultwarden again.
  - loads the WebDAV `rclone.conf` secret and the Restic password secret it needs.

## Repository Layout

The current repository layout is:

- [Chart.yaml](./Chart.yaml): Helm chart metadata
- [values.yaml](./values.yaml): documented chart values for Vaultwarden, storage, ingress, backup, WebDAV, Restic, and affinity
- [Dockerfile.restic](./Dockerfile.restic): custom Restic image build that adds `rclone`
- [README.md](./README.md): project overview and operational assumptions
- [TODOs.md](./TODOs.md): completed work and remaining follow-up items
- [templates/namespace.yaml](./templates/namespace.yaml): target namespace
- [templates/serviceaccount.yaml](./templates/serviceaccount.yaml): Vaultwarden workload service account
- [templates/backup-serviceaccount.yaml](./templates/backup-serviceaccount.yaml): backup job service account
- [templates/rbac.yaml](./templates/rbac.yaml): RBAC that allows the backup job to scale the Vaultwarden `StatefulSet`
- [templates/persistentvolumeclaim.yaml](./templates/persistentvolumeclaim.yaml): shared `ReadWriteOnce` PVC
- [templates/statefulset.yaml](./templates/statefulset.yaml): Vaultwarden `StatefulSet`
- [templates/service.yaml](./templates/service.yaml): Vaultwarden service
- [templates/ingress.yaml](./templates/ingress.yaml): Traefik ingress
- [templates/secrets.yaml](./templates/secrets.yaml): WebDAV `rclone.conf` and Restic password secrets
- [templates/cronjob.yaml](./templates/cronjob.yaml): hourly backup job
- [templates/NOTES.txt](./templates/NOTES.txt): Helm post-install notes

The Vaultwarden container configuration is expected to include `ROCKET_PORT=12345`, matching the prior standalone container run pattern. The Kubernetes `Service` should route to that container port, while external access is expected to come through a Traefik-managed `Ingress`.

The default ingress assumptions for this repository are:

- ingress class: `traefik`
- TLS managed by cert-manager
- cert-manager cluster issuer annotation: `cert-manager.io/cluster-issuer: letsencrypt-staging`

## Backup Scope

Vaultwarden's upstream backup guidance treats the SQLite database and attachments as required backup data. It also recommends backing up files such as `config.json` and the `rsa_key*` files. In this chart, the backup job snapshots the whole Vaultwarden data directory after scaling the `StatefulSet` down so the SQLite database is frozen during the backup window.

That means the backup contains at least:

- `db.sqlite3` via a consistent SQLite-aware backup method
- `attachments/`
- `config.json`
- `rsa_key*`

Optional data such as `sends/` and `icon_cache/` can be included based on retention and storage requirements.

This chart keeps those optional paths included by default because the backup job snapshots the whole `/data` directory. If they are not needed, exclude them with `backupCronJob.excludePaths`.

## Restic Image Requirement

Restic can use an `rclone:` backend, but the stock `docker.io/restic/restic:latest` image does not ship with the `rclone` binary. Running Restic against an `rclone:` repository therefore fails unless `rclone` is also present in the container.

Expected failing pattern with the stock image:

```bash
podman run --rm -it \
  -v rclone.conf:/root/.config/rclone/rclone.conf \
  docker.io/restic/restic:latest \
  -r rclone:remote-webdav:restic-backup backup /root
```

This fails because Restic tries to execute `rclone` and cannot find it in `PATH`.

To support a WebDAV-backed Restic repository, this repository includes [Dockerfile.restic](./Dockerfile.restic), which starts from `docker.io/restic/restic` and copies the `rclone` binary from `docker.io/rclone/rclone`.

When generating the `rclone.conf` secret, the WebDAV password should be stored in the format expected by rclone. Use `rclone obscure` to produce the password value documented by rclone.

This project assumes the Restic repository has already been initialized before the Kubernetes jobs run. In other words, `restic init` is handled out of band, and the scheduled job only performs backup and retention operations against an existing repository.

The intended backup flow is:

1. Scale the Vaultwarden `StatefulSet` down to `0`.
2. Run `restic backup /data` with the `vaultwarden` tag plus a configurable host tag.
3. Scale the Vaultwarden `StatefulSet` back to its configured replica count.
4. Run `restic forget` with retention settings and `--prune`.

The default retention policy keeps:

- the last `24` snapshots
- `30` daily snapshots
- `8` weekly snapshots
- `12` monthly snapshots

This means the job can create multiple snapshots throughout the day, while the longer-term retention naturally settles to one retained daily snapshot after older hourly snapshots age out.

## Image Build And Publish

The runtime backup image should be built from [Dockerfile.restic](./Dockerfile.restic) so the final image contains both `restic` and `rclone`.

Example local build with Podman:

```bash
podman build \
  -f Dockerfile.restic \
  --build-arg RESTIC_IMAGE=docker.io/restic/restic:latest \
  --build-arg RCLONE_IMAGE=docker.io/rclone/rclone:latest \
  -t registry.example.com/infrastructure/vaultwarden-restic:latest \
  .
```

Example local build with Docker:

```bash
docker build \
  -f Dockerfile.restic \
  --build-arg RESTIC_IMAGE=docker.io/restic/restic:latest \
  --build-arg RCLONE_IMAGE=docker.io/rclone/rclone:latest \
  -t registry.example.com/infrastructure/vaultwarden-restic:latest \
  .
```

Example publish flow:

```bash
podman push registry.example.com/infrastructure/vaultwarden-restic:latest
```

After publishing, update [values.yaml](./values.yaml) or your Helm override file so `images.restic.repository` and `images.restic.tag` point at the published image.

Recommended tagging approach:

- immutable release tags such as `2026-04-20` or `1.0.0`
- an environment-specific floating tag only if your deployment process requires it
- matching `images.restic.tag` overrides in the Helm values used by each environment

## Deployment Examples

Example install:

```bash
helm upgrade --install vaultwarden-backup . \
  --namespace vaultwarden \
  --create-namespace \
  --set images.restic.repository=registry.example.com/infrastructure/vaultwarden-restic \
  --set images.restic.tag=latest
```

Example install with existing PVC and optional paths excluded:

```bash
helm upgrade --install vaultwarden-backup . \
  --namespace vaultwarden \
  --create-namespace \
  --set vaultwarden.persistence.existingClaim=vaultwarden-data \
  --set backupCronJob.excludePaths[0]=sends \
  --set backupCronJob.excludePaths[1]=icon_cache
```

## Restore Procedure

High-level restore flow:

1. Scale the Vaultwarden `StatefulSet` down to `0`.
2. Restore the desired Restic snapshot into a temporary directory.
3. Replace the contents of the Vaultwarden PVC with the restored data.
4. Verify ownership and permissions as required by your environment.
5. Scale the Vaultwarden `StatefulSet` back up.
6. Validate login, attachments, and any expected organization data.

Example restore command:

```bash
restic -r rclone:remote-webdav:restic-backup restore latest --target /restore
```

Because this chart backs up the full `/data` directory, restore should replace the whole Vaultwarden data tree as one unit rather than selectively restoring only the SQLite file.

## Operational Runbook

Routine operating steps:

1. Verify the custom Restic image is published and referenced by `images.restic`.
2. Verify the Restic repository has already been initialized.
3. Verify the WebDAV secret contains an obscured `rclone` password.
4. Run the validation script before release changes.
5. Render the chart with environment overrides and inspect the output.
6. Deploy with `helm upgrade --install`.
7. Trigger a manual backup job once and review logs before relying on the schedule.

Manual job trigger example:

```bash
kubectl -n vaultwarden create job --from=cronjob/vaultwarden-backup-backup vaultwarden-backup-manual
```

## Validation

This repository includes [scripts/validate.sh](./scripts/validate.sh) to run a broader validation pass than a single `helm lint`.

The script currently runs:

- `helm lint`
- default `helm template`
- `helm template` with an existing PVC override and ingress disabled

Example:

```bash
./scripts/validate.sh
```

## Planned Security Improvement

Another planned improvement is to encrypt backup artifacts with OpenPGP for a public-key recipient before or during the remote backup flow. This would add recipient-based encryption on top of the remote storage path so backups are not only protected by transport and repository credentials.

## Storage And Scheduling Assumptions

The shared Vaultwarden data volume is expected to use a `ReadWriteOnce` PVC. Because the Vaultwarden pod and the backup job both mount the same PVC at `/data`, the default scheduling model should keep those pods on the same node.

This repository assumes:

- one writer workload for the Vaultwarden data volume
- one backup job that mounts the same PVC while Vaultwarden is scaled down
- default affinity rules that keep the pods using the shared PVC on the same node

## Planned Kubernetes Components

- `StatefulSet` for Vaultwarden
- `Service` for Vaultwarden access
- `PersistentVolumeClaim` with `5Gi` capacity
- backup `CronJob` running every hour
- dedicated backup `ServiceAccount`, `Role`, and `RoleBinding`
- WebDAV and Restic password `Secret` objects
- image build flow for the custom Restic image with bundled `rclone`

## Repository Status

This repository now contains a working Helm chart skeleton for the Vaultwarden deployment model described above. It renders a namespace, service accounts, PVC, Vaultwarden `StatefulSet`, service, ingress, WebDAV and Restic secrets, the backup `CronJob`, the backup RBAC resources, and the custom `Dockerfile.restic`.

The remaining work is mainly operational hardening and refinement of the backup implementation.

All entries in `values.yaml` should be documented with comments so the chart configuration remains readable and maintainable.

## References

- Vaultwarden repository: https://github.com/dani-garcia/vaultwarden
- Vaultwarden backup guidance: https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault
- Vaultwarden environment template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/refs/heads/main/.env.template
- Restic repository preparation via rclone: https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html#other-services-via-rclone
- rclone obscure command: https://rclone.org/commands/rclone_obscure/
