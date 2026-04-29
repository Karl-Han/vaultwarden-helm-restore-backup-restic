Helm Quick Start
================

This guide describes the intended Helm-based startup flow once the Helm chart is generated from ``devops/k8s``.

Important note
--------------

The Helm chart is not the active source of truth yet. The active implementation is still the prototype under ``devops/k8s`` plus ``devops/Dockerfile.restic``.

This guide exists to define the expected operator flow for the future Helm packaging.

Assumptions
-----------

This quick start assumes:

- Traefik is already installed
- cert-manager is already installed
- ``kubectl get all -n cert-manager`` works
- the target StorageClass already exists
- the custom Restic backup image has already been built and published
- the required secrets for Restic password and rclone config are available

Fresh start
-----------

1. Install the Helm chart with the required values for:

   - Vaultwarden image
   - storage class and PVC size
   - ingress host and TLS
   - Restic repository
   - rclone config secret
   - Restic password secret
   - backup schedule

2. Verify the PVC, StatefulSet, service, and ingress are created.

3. Verify the backup CronJob is created with the expected environment and secret mounts.

Restore-oriented start
----------------------

If restoring an existing deployment, the intended Helm operator flow is:

1. Install the Helm chart in initialization mode with the Vaultwarden StatefulSet scaled to ``0``.

2. Restore the existing database and data set into ``/data``.

   This may be done through:

   - a Vaultwarden backup helper flow based on ``devops/k8s/deploy-vw-backup.yaml``
   - a Restic-based restore helper pod using the custom image from ``devops/Dockerfile.restic``

3. Scale the Vaultwarden StatefulSet to ``1``.

4. Verify the application starts correctly.

5. Allow the scheduled backup CronJob to take over recurring backups.

What should not be done in real quick start
-------------------------------------------

The following local-development step should not be part of the real Helm quick start:

.. code-block:: bash

   kubectl create -n vw-test secret tls vaultwarden-tls \
     --cert=cert.pem \
     --key=key.pem

That step is only for local prototype deployment. Real quick start assumes Traefik and cert-manager handle the TLS path.
