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

1. Create a local TLS secret for Vaultwarden:

   .. code-block:: bash

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

   Then attach a shell to the pod and follow the restore process from:

   - https://github.com/ttionya/vaultwarden-backup

7. If you need to restore from an existing Restic repository instead, build ``devops/Dockerfile.restic`` and run a restore-oriented helper pod based on the same mounting pattern as ``devops/k8s/deploy-vw-backup.yaml``.

   The intent is to pass the required environment variables and run:

   .. code-block:: bash

      python /app/main.py restore

   Note:

   The current Python entrypoint in ``main.py`` implements the backup flow, not a restore subcommand yet. A restore-specific wrapper or command variant is still implied operational work.

8. Scale the Vaultwarden StatefulSet back to ``1`` for normal operation:

   .. code-block:: bash

      kubectl scale -n vw-test sts/vaultwarden --replicas=1

9. Build the backup image from ``devops/Dockerfile.restic`` and schedule it as a cron-based workload, either in the system or in Kubernetes, in the same namespace.

Runtime environment
-------------------

The backup image expects the environment variables defined in ``envrc.template``:

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

1. Validate the Vaultwarden data directory.
2. Validate the existence of the rclone config file, defaulting to ``~/.config/rclone/rclone.conf``.
3. Validate the Restic password configuration.
4. Scale the target StatefulSet down to ``0`` using the Kubernetes Python client.
5. Run ``restic backup`` against ``VW_DATA_DIR``.
6. Run ``restic forget --prune`` with the configured retention policy.
7. Scale the StatefulSet back to its original replica count.

Real deployment notes
---------------------

The local TLS secret creation step is only for local development.

In a real deployment, TLS should be handled through Traefik and cert-manager. The expected direction is:

- Traefik is already installed
- ``kubectl get all -n cert-manager`` succeeds
- ingress and certificate management are handled by cluster components instead of a manually created TLS secret
