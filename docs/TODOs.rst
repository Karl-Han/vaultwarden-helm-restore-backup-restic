Helm Implementation Plan
========================

This document tracks the implementation plan for generating a Helm chart from the ``devops/k8s`` prototype.

Current assumption
------------------

The Helm chart should be generated from the behavior already proven by:

- ``devops/k8s/sts_vaultwarden.yaml``
- ``devops/k8s/deploy-vw-backup.yaml``
- ``devops/Dockerfile.restic``
- ``main.py``

Implementation plan
-------------------

1. Convert ``devops/k8s/sts_vaultwarden.yaml`` into Helm-managed resources.

   - StatefulSet
   - service
   - ingress class integration
   - ingress
   - cert-manager annotations and TLS wiring
   - namespace
   - PVC or volume claim template

2. Convert ``devops/k8s/deploy-vw-backup.yaml`` into a Helm-managed restore helper deployment with proper parameters.

   - image settings
   - namespace
   - PVC attachment
   - command override support
   - environment variable injection
   - replica count defaulting to ``0``

3. Create a Helm-managed restore deployment for ``devops/Dockerfile.restic`` by imitating ``devops/k8s/deploy-vw-backup.yaml``.

   - mount the Vaultwarden PVC
   - inject the required Restic and rclone environment variables
   - allow shell-based restore workflows
   - replica count defaulting to ``0``

4. Model the backup runtime image from ``devops/Dockerfile.restic``.

   - Python 3.12 base
   - Restic binary
   - rclone binary
   - Python dependencies from ``pyproject.toml``
   - ``python /app/main.py`` entrypoint

5. Convert the backup workflow into Kubernetes workload templates.

   - CronJob
   - Restic backup deployment
   - service account
   - RBAC for StatefulSet and deployment scaling
   - environment variable injection
   - secret resources for the required environment variables
   - secret mounts or env wiring for Restic password and rclone config

6. Add initialization and maintenance support.

   - deploy StatefulSet with replicas set to ``0`` when needed
   - allow manual restore into ``/data``
   - keep both restore-oriented deployments scaled to ``0`` by default
   - scale restore deployments to ``1`` only when restoration work is required
   - document the scale-down and scale-up process

7. Encode storage assumptions as values.

   - StorageClass
   - PVC size
   - mount path ``/data``
   - ``ReadWriteOnce`` expectation

8. Add values for backup behavior.

   - Restic repository
   - host tag
   - backup tag
   - exclude paths
   - timeout and polling values

9. Add values for restore-oriented helper deployments.

   - vaultwarden-backup deployment replica count
   - Restic restore deployment replica count
   - image references
   - commands and environment variables

10. Add validation and render checks.

   - ``helm lint``
   - ``helm template``
   - scenario overrides

Definition of done
------------------

The Helm implementation should be considered ready when:

- it is generated from the ``devops/k8s`` prototype behavior
- it supports fresh install and restore-oriented initialization
- it includes two restore-oriented deployments that default to ``0`` replicas
- it supports scheduled backups through a CronJob plus a Restic backup deployment
- it documents local prototype mode versus real deployment mode
- it renders cleanly with ``helm lint`` and ``helm template``
