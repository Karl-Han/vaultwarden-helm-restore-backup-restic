Development Workflow
====================

This document describes the current end-to-end workflow for setting up and validating this project.

Source of truth
---------------

At this stage, the source of truth is the prototype implementation:

- ``devops/k8s/sts_vaultwarden.yaml``
- ``devops/k8s/deploy-vw-backup.yaml``
- ``devops/Dockerfile.restic``
- ``main.py``

The Helm chart is a later packaging step derived from the Kubernetes prototype. It is not the primary implementation target yet.

Prerequisites
-------------

You should have:

- Kubernetes access with ``kubectl``
- a working StorageClass, for example ``openebs-lvmpv`` backed by ``local.csi.openebs.io``
- Traefik available for ingress in real deployments
- cert-manager available for later TLS automation in real deployments
- Restic repository access
- rclone configuration for the WebDAV remote

For local prototyping, a built-in TLS secret may be used. This is a local-development convenience, not the intended real deployment flow.

Local prototype workflow
------------------------

1. Create a local TLS secret for Vaultwarden temporarily for testing purpose:

   .. code-block:: bash

      # openssl req -x509 -nodes -days 365 \
      #   -newkey rsa:2048 \
      #   -keyout key.pem \
      #   -out cert.pem \
      #   -subj "/CN=example.com/O=example"
      kubectl create -n vw-test secret tls vaultwarden-tls \
        --cert=cert.pem \
        --key=key.pem

2. Confirm the target StorageClass exists. Example expectation:

   - name: ``openebs-lvmpv``
   - provisioner: ``local.csi.openebs.io``

3. Apply the prototype StatefulSet and PVC definition:

   .. code-block:: bash

      kubectl apply -n vw-test -f devops/k8s/sts_vaultwarden.yaml

4. If you need a fresh deployment, continue directly to step 7.

5. If you need to restore an existing Vaultwarden data set, scale the StatefulSet down to ``0`` first:

   .. code-block:: bash

      kubectl scale -n vw-test sts/vaultwarden --replicas=0

6. Restore existing Vaultwarden data using the prototype helper deployment:

   .. code-block:: bash

      kubectl apply -n vw-test -f devops/k8s/deploy-vw-backup.yaml

   Then make sure the restore zip file is available as ``backup.YYYYMMDD.zip`` in a local folder that is mounted to ``/bitwarden/restore`` inside the helper container.

   This is required because ``/app/entrypoint.sh restore`` only searches ``/bitwarden/restore``.

   In order to attach to the pod, you can execute: `kubectl exec -it pods/vw-dep-vaultwarden-backup-vaultwarden-backup-6bf6c896d8-d7gk7 -- bash`.

   Example restore command inside the pod:

   .. code-block:: bash

      /app/entrypoint.sh restore --zip-file backup.20260501.zip -p

   The restore process will overwrite the existing data already mounted from the Vaultwarden PVC.

   Follow the helper image restore workflow from:

   - https://github.com/ttionya/vaultwarden-backup

7. If you need to restore from an existing Restic repository instead, build ``devops/Dockerfile.restic`` 
   and run a restore-oriented helper pod based on the same mounting pattern as ``devops/k8s/deploy-vw-backup.yaml``.

   Pass the required environment variables and run:

   .. code-block:: bash

      python /app/main.py restore

   The restore command performs the same Kubernetes scaling orchestration as the backup command:

   1. validate the configured Vaultwarden data directory path
   2. validate the rclone configuration path
   3. validate the Restic password configuration
   4. scale the target StatefulSet down to ``0``
   5. run ``restic restore <snapshot> --target <restore-target> --include <data-dir>``
   6. scale the StatefulSet back to its original replica count

   By default, ``--snapshot`` is ``latest`` and ``--restore-target`` is ``/``.

   This means the restore container filesystem and volume mounts must be arranged so that restoring ``/data`` 
   back into ``/`` writes into the intended Vaultwarden PVC mount.

8. Scale the Vaultwarden StatefulSet back to ``1`` for normal operation:

   .. code-block:: bash

      kubectl scale -n vw-test sts/vaultwarden --replicas=1

9. Build the backup image from ``devops/Dockerfile.restic`` and schedule it as a cron-based workload, either in the system or in Kubernetes, in the same namespace.

Runtime environment
-------------------

The backup and restore image expects the environment variables defined in ``envrc.template``:

- ``RESTIC_PASSWORD`` or ``RESTIC_PASSWORD_FILE``
- ``VAULTWARDEN_NAMESPACE``
- ``VAULTWARDEN_STATEFULSET``
- ``VW_DATA_DIR``
- ``RESTIC_REPOSITORY``
- ``RCLONE_CONFIG``
- ``HOST_TAG``
- ``BACKUP_TAG``
- ``SCALE_DOWN_TIMEOUT_SECONDS``
- ``SCALE_DOWN_POLL_INTERVAL_SECONDS``

Python backup behavior
----------------------

The Python entrypoint performs the following flow:

#. Validate 
  - the Vaultwarden data directory path
  - the existence of the rclone config file, defaulting to ``~/.config/rclone/rclone.conf``.
  - the Restic password configuration.
#. Scale the target StatefulSet down to ``0`` using the Kubernetes Python client.
#. Run ``restic backup`` against ``VW_DATA_DIR``.
#. Run ``restic forget --prune`` with the configured retention policy.
#. Scale the StatefulSet back to its original replica count.

Python restore behavior
-----------------------

The Python restore command performs the following flow:

#. Validate 
  - the Vaultwarden data directory path.
  - the existence of the rclone config file, defaulting to ``~/.config/rclone/rclone.conf``.
  - the Restic password configuration.
#. Scale the target StatefulSet down to ``0`` using the Kubernetes Python client.
#. Run ``restic restore`` for the selected snapshot, using ``--target`` and ``--include`` for ``VW_DATA_DIR``.
#. Scale the StatefulSet back to its original replica count.
