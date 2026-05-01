# devops/helm

This chart is the Helm packaging of the Vaultwarden backup prototype defined under `devops/k8s` and `devops/Dockerfile.restic`.

## Component Overview

The chart contains these main components:

- `PersistentVolumeClaim`
  Purpose: provide the shared `ReadWriteOnce` volume mounted at `/data` by Vaultwarden and the backup or restore workloads.

- `StatefulSet`
  Purpose: run the main Vaultwarden application with persistent storage.

- headless `Service`
  Purpose: act as the governing service for the Vaultwarden `StatefulSet`.

- application `Service`
  Purpose: expose Vaultwarden inside the cluster for ingress routing.

- `IngressClass`
  Purpose: optionally define the Traefik ingress class when the cluster does not already provide it.

- `Ingress`
  Purpose: expose Vaultwarden externally and carry cert-manager annotations for TLS issuance.

- Vaultwarden `ServiceAccount`
  Purpose: identity for the main Vaultwarden application pod.

- backup `ServiceAccount`
  Purpose: identity for backup and restore workloads that need Kubernetes API access.

- `Role` and `RoleBinding`
  Purpose: allow the CronJob and Restic helper workloads to scale the Vaultwarden `StatefulSet` and the Restic backup deployment.

- vaultwarden-backup `Deployment`
  Purpose: manual restore helper derived from `devops/k8s/deploy-vw-backup.yaml`, using `docker.io/ttionya/vaultwarden-backup`.
  Default behavior: `0` replicas. Scale to `1` only when restore work is needed.

- Restic backup `Deployment`
  Purpose: helper workload that mounts the PVC and runs `python /app/main.py backup` in an init container.
  Default behavior: `0` replicas. The CronJob scales it to `1` only while a backup is running.

- Restic restore `Deployment`
  Purpose: manual restore helper based on the custom Restic image from `devops/Dockerfile.restic`.
  Default behavior: `0` replicas. Scale to `1` only when restore work is needed.

- backup `CronJob`
  Purpose: scheduled control-plane runner that scales Vaultwarden down, scales the Restic backup deployment up, waits for the init-container backup to finish, then scales everything back to the steady state.

- rclone config `Secret`
  Purpose: provide `rclone.conf` for Restic's `rclone:` backend.

- Restic env `Secret`
  Purpose: provide the runtime environment variables consumed by `main.py`, including repository settings and scale timing values.

## Template Map

- `templates/statefulset.yaml`
  Purpose: Vaultwarden StatefulSet.

- `templates/services.yaml`
  Purpose: headless service and application service.

- `templates/ingressclass.yaml`
  Purpose: optional ingress class definition.

- `templates/ingress.yaml`
  Purpose: external ingress and TLS routing.

- `templates/persistentvolumeclaim.yaml`
  Purpose: standalone PVC creation.

- `templates/serviceaccount.yaml`
  Purpose: Vaultwarden service account.

- `templates/backup-serviceaccount.yaml`
  Purpose: backup and restore service account.

- `templates/rbac.yaml`
  Purpose: permissions for scaling the StatefulSet and the Restic backup deployment.

- `templates/deployments.yaml`
  Purpose: the `vaultwarden-backup` helper deployment, the Restic backup deployment, and the Restic restore deployment.

- `templates/cronjob.yaml`
  Purpose: scheduled backup orchestration job.

- `templates/secrets.yaml`
  Purpose: rclone config secret and Restic environment secret.

- `templates/NOTES.txt`
  Purpose: post-install notes for operators.

## Important Values

The main value groups are:

- `vaultwarden`
  Purpose: StatefulSet, service, ingress, TLS, and PVC settings for the main application.

- `vaultwardenBackup`
  Purpose: settings for the `ttionya/vaultwarden-backup` helper deployment.

- `vaultwardenRestic`
  Purpose: settings for the custom Restic image, backup deployment, restore deployment, cronjob schedule, and runtime environment.

- `rclone`
  Purpose: location and content of `rclone.conf`.

- `serviceAccount` and `backupServiceAccount`
  Purpose: service account settings for the application and backup/restore workloads.

## Operational Model

The intended operator workflow is:

1. Install the chart.
2. Allow the Vaultwarden `StatefulSet` to run normally.
3. Use the backup `CronJob` to scale the application down and temporarily scale the Restic backup deployment up.
4. Leave both restore-oriented deployments at `0` replicas until restoration is required.
5. Scale one of the restore deployments to `1` only for manual restore work, then scale it back to `0`.
