# Helm Chart Overview

This chart packages the Kubernetes deployment model for running Vaultwarden together with the backup, restore, and archive workflows used by this repository.

The chart should be understood in terms of the main operational workflows it provides, not as a list of raw Kubernetes objects.

## 1. Run Vaultwarden with persistent storage

The first purpose of the chart is to run the main Vaultwarden service on a persistent volume.

To make that work, the chart provides:

- a persistent data volume mounted at the Vaultwarden data path
- the main Vaultwarden workload
- internal service exposure for the application
- optional ingress and TLS configuration for external access
- the service account and related wiring required by the application pod

This is the steady-state workload. In normal operation, Vaultwarden runs continuously from the PVC and serves traffic through the configured service and ingress path.

## 2. Restore from a Vaultwarden zip backup

The chart includes a `vaultwarden-backup` helper deployment based on the `ttionya/vaultwarden-backup` project.

Its purpose in this chart is manual restore from a zip backup into the shared Vaultwarden data volume. The deployment stays scaled to `0` by default and is only scaled up when an operator needs it.

To support that purpose, the chart also provides the shared volume mount and the surrounding configuration required for the helper pod to work against the same persistent data as the main Vaultwarden workload.

Although the upstream helper project also supports backup functions, this chart currently treats it primarily as a restore helper because that is the tested operational path here.

## 3. Back up the Vaultwarden data directory to a remote Restic repository

The chart includes a custom Restic backup path built around the image from `devops/Dockerfile.restic` and the Python CLI in `main.py`.

Its purpose is to perform recurring backups of the Vaultwarden data directory to a remote Restic repository through rclone.

The workflow is:

1. the scheduled backup controller starts
2. Vaultwarden is scaled down to protect the data during backup
3. the Restic backup helper is scaled up
4. the helper runs `python /app/main.py backup`
5. the helper performs `restic backup` and `restic forget --prune`
6. the helper finishes
7. Vaultwarden is scaled back to its original replica count

To make that workflow work safely, the chart also creates:

- the dedicated helper deployment that mounts the same Vaultwarden PVC
- the scheduled orchestrator job that coordinates scaling
- the service account and RBAC permissions needed to scale workloads through the Kubernetes API
- the secret data needed for Restic repository access and rclone configuration

The backup helper deployment stays at `0` replicas during steady state. The scheduled controller scales it up only for the duration of the backup run.

## 4. Restore from the remote Restic repository

The chart also includes a manual Restic restore deployment that uses the same custom image and shared PVC.

Its purpose is operator-driven restore from the remote Restic repository back into the Vaultwarden data directory.

The restore workflow is:

1. scale the main Vaultwarden workload down
2. scale the Restic restore helper up
3. run `python /app/main.py restore`
4. restore the selected snapshot into the mounted filesystem layout
5. scale the helper back down
6. scale Vaultwarden back up

Like the zip restore helper, this deployment stays at `0` replicas by default and is only used when restore work is needed.

## 5. Archive the remote Restic repository into AWS S3

The chart includes a second scheduled workflow whose purpose is different from the Vaultwarden data backup flow.

Instead of backing up the live Vaultwarden PVC directly, this workflow backs up the remote Restic repository itself into AWS S3.

The workflow is:

1. connect to the remote path that stores the Restic repository
2. copy that remote content into a temporary local working directory
3. package the copied content as a `tar.gz`
4. upload the archive to one or more configured rclone targets, such as an S3 bucket

This creates another layer of retention on top of the remote Restic repository and is the place where the Terraform-managed S3 buckets and credentials are used.

To make that work, the chart also provides:

- the archive `CronJob`
- the archive environment secret
- access to the shared rclone configuration secret
- the temporary in-pod workspace needed to assemble the archive before upload

## Supporting configuration

Several pieces exist only to support the main workflows above:

- shared storage configuration for the Vaultwarden data volume
- ingress and TLS settings for the live application
- service accounts and RBAC rules for workloads that need Kubernetes API access
- the rclone configuration secret
- Restic environment variables and timing configuration
- archive source, target, and path-prefix settings

These are supporting pieces, not the primary story of the chart.

## Main values to understand first

If you are configuring the chart, start with these value groups:

- `vaultwarden`
  Purpose: live application settings, storage, service, ingress, and TLS behavior.

- `vaultwardenBackup`
  Purpose: manual zip-based restore helper using `ttionya/vaultwarden-backup`.

- `vaultwardenRestic`
  Purpose: custom Restic image settings, automated backup behavior, manual Restic restore behavior, and scheduled orchestration.

- `vaultwardenArchive`
  Purpose: scheduled archive of the remote Restic repository into rclone targets such as S3.

- `rclone`
  Purpose: rclone configuration content and mount location used by Restic and archive workflows.

- `serviceAccount` and `backupServiceAccount`
  Purpose: identities for the application and the backup or restore workflows.

## Operator model

The intended operator model is:

1. install the chart with Vaultwarden, Restic, rclone, storage, ingress, and secret configuration
2. run Vaultwarden normally from the persistent volume
3. allow the Restic backup `CronJob` to protect the live Vaultwarden data directory on schedule
4. optionally enable the archive `CronJob` to copy the remote Restic repository into S3
5. leave both restore helpers scaled to `0` until restore work is required
6. choose the restore helper based on the recovery source:
   - `vaultwarden-backup` for zip-based restore
   - Restic restore helper for snapshot restore from the remote Restic repository
