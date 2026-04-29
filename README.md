# vaultwarden_backup

Vaultwarden backup automation with two parallel tracks:

- prototyping with raw Kubernetes manifests and a custom Restic image
- implementation and packaging with Helm

## Development Phases

Development is split into two steps.

### 1. Prototyping

The prototype phase is built from:

- [devops/k8s/deploy-vw-backup.yaml](/home/iwktd/k8s_deployments/vaultwarden_backup/devops/k8s/deploy-vw-backup.yaml)
- [devops/k8s/sts_vaultwarden.yaml](/home/iwktd/k8s_deployments/vaultwarden_backup/devops/k8s/sts_vaultwarden.yaml)
- [devops/Dockerfile.restic](/home/iwktd/k8s_deployments/vaultwarden_backup/devops/Dockerfile.restic)

This phase is used to validate the operational flow first:

- Vaultwarden runs from a `StatefulSet`
- the PVC is mounted at `/data`
- a custom image contains Python, Restic, and rclone
- the backup process scales the `StatefulSet` down, runs Restic, then scales it back up

### 2. Helm Implementation

The Helm phase packages the same behavior into chart-managed resources under `devops/helm`.

The goal of the Helm phase is to make the prototype reproducible and configurable:

- namespace
- Vaultwarden image and ingress
- PVC settings
- backup schedule
- WebDAV and Restic settings
- service accounts and RBAC

## Repository Layout

- [main.py](/home/iwktd/k8s_deployments/vaultwarden_backup/main.py): Python backup entrypoint
- [pyproject.toml](/home/iwktd/k8s_deployments/vaultwarden_backup/pyproject.toml): Python dependencies
- [envrc.template](/home/iwktd/k8s_deployments/vaultwarden_backup/envrc.template): expected runtime environment variables
- [devops/Dockerfile.restic](/home/iwktd/k8s_deployments/vaultwarden_backup/devops/Dockerfile.restic): custom backup image
- [devops/k8s](/home/iwktd/k8s_deployments/vaultwarden_backup/devops/k8s): prototype Kubernetes manifests
- [devops/helm](/home/iwktd/k8s_deployments/vaultwarden_backup/devops/helm): Helm implementation area
- [scripts/validate.sh](/home/iwktd/k8s_deployments/vaultwarden_backup/scripts/validate.sh): validation helper

## Backup Behavior

The Python entrypoint performs this flow:

1. Load Kubernetes configuration using the Python Kubernetes client.
2. Check that the Vaultwarden data directory exists.
3. Check that the rclone config file exists.
   Default path: `~/.config/rclone/rclone.conf`
4. Check that the Restic password is available through `RESTIC_PASSWORD`, `RESTIC_PASSWORD_FILE`, or `--password-file`.
5. Scale the target `StatefulSet` down to `0`.
6. Run:

```bash
restic backup "$VW_DATA_DIR" \
  --tag vaultwarden \
  --tag "$HOST_TAG" \
  --exclude-file "$TMP_EXCLUDES"
```

7. Run:

```bash
restic forget \
  --tag vaultwarden \
  --keep-last 24 \
  --keep-daily 30 \
  --keep-weekly 8 \
  --keep-monthly 12 \
  --prune
```

8. Scale the `StatefulSet` back to its original replica count.

## Runtime Environment

The container and local workflow expect the variables defined in [envrc.template](/home/iwktd/k8s_deployments/vaultwarden_backup/envrc.template).

Important variables:

- `VAULTWARDEN_NAMESPACE`
- `VAULTWARDEN_STATEFULSET`
- `VW_DATA_DIR`
- `RESTIC_REPOSITORY`
- `RCLONE_CONFIG`
- `RESTIC_PASSWORD` or `RESTIC_PASSWORD_FILE`
- `HOST_TAG`
- `BACKUP_TAG`

## Actual Deployment Flow

In actual deployment, the steps are:

1. Install the Helm chart together with the required configuration for Restic, rclone, WebDAV, secrets, and the backup job.
2. Optionally scale the Vaultwarden `StatefulSet` down and restore an existing database and data set into `/data`.
3. Scale the `StatefulSet` back up.

That means the initial restore path is manual and separate from the recurring backup flow.

## Initialization And Maintenance

For initialization or maintenance work, the desired pattern is:

1. Create the PVC and related resources.
2. Create the Vaultwarden `StatefulSet` with replica count set to `0` so the volume exists and is ready.
3. Manually restore or copy the existing Vaultwarden data into `/data`.
4. Scale the Vaultwarden `StatefulSet` to `1` when the data is ready.

This keeps restoration separate from the scheduled backup process.

## Image Notes

The backup image must contain:

- Python 3.12
- the Python dependencies from [pyproject.toml](/home/iwktd/k8s_deployments/vaultwarden_backup/pyproject.toml)
- `restic`
- `rclone`

The container entrypoint should run:

```bash
python /app/main.py
```

so runtime flags can still be passed to the Python CLI.

## References

- Vaultwarden repository: https://github.com/dani-garcia/vaultwarden
- Vaultwarden backup guidance: https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault
- Vaultwarden environment template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/refs/heads/main/.env.template
- Restic repository preparation via rclone: https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html#other-services-via-rclone
- rclone obscure command: https://rclone.org/commands/rclone_obscure/
