# TODOs

## Todo

- None at the moment.

## Done

- Initialized the repository as a Helm chart project.
- Added a project overview in [README.md](/home/iwktd/k8s_deployments/vaultwarden_backup/README.md).
- Documented the current repository and chart layout in [README.md](/home/iwktd/k8s_deployments/vaultwarden_backup/README.md).
- Documented the required architecture: Vaultwarden workload, shared PVC, and a single Restic backup cron job.
- Documented the `restic + rclone` container requirement for WebDAV-backed Restic repositories.
- Replaced the default Helm starter templates with Vaultwarden-specific manifests.
- Added a `StatefulSet` for Vaultwarden using `docker.io/vaultwarden/server:latest`.
- Added a `PersistentVolumeClaim` sized at `5Gi` for the Vaultwarden data directory.
- Added the service and Traefik ingress configuration for Vaultwarden access.
- Reworked `values.yaml` around Vaultwarden, storage, WebDAV, Restic, namespace, and affinity settings.
- Added a backup `CronJob` that runs every hour, scales the Vaultwarden `StatefulSet` down, runs Restic, applies retention, and scales Vaultwarden back up.
- Added a dedicated backup service account plus RBAC for scaling the Vaultwarden `StatefulSet`.
- Added Kubernetes secrets for the WebDAV `rclone.conf` content and the Restic password.
- Added `Dockerfile.restic` to bundle `rclone` into the Restic image.
- Added Helm notes and verified the chart with `helm lint` and `helm template`.
- Added image build, tagging, publishing, and deployment examples to [README.md](/home/iwktd/k8s_deployments/vaultwarden_backup/README.md).
- Documented that optional Vaultwarden paths remain included by default and can be excluded with `backupCronJob.excludePaths`.
- Added restore procedure and operational runbook sections to [README.md](/home/iwktd/k8s_deployments/vaultwarden_backup/README.md).
- Added [scripts/validate.sh](/home/iwktd/k8s_deployments/vaultwarden_backup/scripts/validate.sh) for broader validation coverage.
- Added explicit timeout handling for the scale-down wait loop in [templates/cronjob.yaml](/home/iwktd/k8s_deployments/vaultwarden_backup/templates/cronjob.yaml).
