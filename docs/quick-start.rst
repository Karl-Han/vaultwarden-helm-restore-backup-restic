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

Pre-install Restic Prerequisites
--------------------------------

Before Helm install, initialize the Restic repository at the target rclone remote path.

Also make sure the remote name used in the Restic repository URL matches the remote name defined inside the ``rclone.conf`` content in the Helm values.

Example expectation:

- ``RESTIC_REPOSITORY`` uses ``rclone:remote-webdav:restic-backup``
- the mounted ``rclone.conf`` contains a section named ``[remote-webdav]``

Initialize the repository before installation, for example:

.. code-block:: bash

   restic -r rclone:remote-webdav:restic-backup init

If the remote name in the repository URL and the remote name in ``rclone.conf`` do not match, the backup and restore workloads will fail when Restic invokes rclone.

Fresh start
-----------

1. Update ``devops/helm/values.yaml`` with the correct public domain and TLS settings.

   At minimum, verify:

   - ``vaultwarden.domains``
   - ``vaultwarden.ingress.path``
   - ``vaultwarden.ingress.tls.secretName``

2. Install the Helm chart with the required values for:

   - Vaultwarden image
   - storage class and PVC size
   - ingress host and TLS
   - Restic repository
   - rclone config secret
   - Restic password secret
   - backup schedule

3. Verify the PVC, StatefulSet, service, and ingress are created.

4. Verify the backup CronJob is created with the expected environment and secret mounts.

5. (Optional) Scale StatefulSet to 0 and scale one of the deployment to 1 for restoration.
   Look for details in the below sections.

Switch From Staging To Production TLS
-------------------------------------

After Helm install, test the real domain over HTTPS first while using the staging issuer.

The default example uses:

- ``cert-manager.io/cluster-issuer: letsencrypt-staging``

Once the domain, ingress, and certificate flow are confirmed working, change the issuer to the production issuer, typically:

- ``cert-manager.io/cluster-issuer: letsencrypt-prod``

This is usually done in:

- ``vaultwarden.ingress.annotations``

Then upgrade the release again so cert-manager requests a production certificate instead of a staging certificate.

Typical sequence:

1. Deploy with ``letsencrypt-staging``.
2. Confirm the domain resolves correctly and HTTPS works through Traefik.
3. Change the issuer annotation to ``letsencrypt-prod``.
4. Run ``helm upgrade`` again.
5. Confirm the production certificate is issued and attached to the ingress.

Restore-oriented start
----------------------

If restoring an existing deployment, first install the chart in initialization mode with the Vaultwarden StatefulSet scaled to ``0``.

That keeps the PVC available while preventing the application from starting before the data is ready.

Restore with vaultwarden-backup
-------------------------------

Use this path when restoring with the ``ttionya/vaultwarden-backup`` helper image.

1. Scale the helper deployment from ``0`` to ``1``:

   - ``vw-dep-vaultwarden-backup-vaultwarden-backup``

2. Make sure the restore zip file is available in a local directory as:

   - ``backup.YYYYMMDD.zip``

3. Mount that local directory into the helper container at ``/bitwarden/restore``.

   This is required because ``/app/entrypoint.sh restore`` searches that path for the restore zip.

   Reference container behavior:

   .. code-block:: bash

      docker run --rm -it \
        --mount type=bind,source=$(pwd),target=/bitwarden/restore/ \
        -e DATA_DIR="/data" \
        ttionya/vaultwarden-backup:latest restore \
        [OPTIONS]

4. Attach to the helper pod and run the restore command, for example:

   .. code-block:: bash

      /app/entrypoint.sh restore --zip-file backup.20260501.zip -p

   Example interactive prompt:

   .. code-block:: text

      Restore will overwrite the existing files, continue? (y/N)
      (Default: n): y

5. The mounted Vaultwarden PVC data will be overwritten by the restore process.

6. Scale the helper deployment back to ``0`` after the restore is complete.

7. Scale the Vaultwarden StatefulSet to ``1``.

8. Verify the application starts correctly.

9. Allow the scheduled backup CronJob to take over recurring backups.

Restore with vaultwardenRestic
------------------------------

Use this path when restoring from an existing Restic repository with the custom image from ``devops/Dockerfile.restic``.

1. Scale the restore deployment from ``0`` to ``1``:

   - ``vw-dep-vaultwarden-backup-restic-restore``

2. Use the restore deployment with the appropriate environment and command arguments so it runs:

   .. code-block:: bash

      python /app/main.py restore

3. Restore the required snapshot into the mounted Vaultwarden data volume.

4. Scale the restore deployment back to ``0`` after the restore is complete.

5. Scale the Vaultwarden StatefulSet to ``1``.

6. Verify the application starts correctly.

7. Allow the scheduled backup CronJob to take over recurring backups.

What should not be done in real quick start
-------------------------------------------

The following local-development step should not be part of the real Helm quick start:

.. code-block:: bash

   kubectl create -n vw-test secret tls vaultwarden-tls \
     --cert=cert.pem \
     --key=key.pem

That step is only for local prototype deployment. Real quick start assumes Traefik and cert-manager handle the TLS path.
