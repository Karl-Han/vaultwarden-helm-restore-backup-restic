from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import click
from kubernetes import client, config
from kubernetes.client import AppsV1Api
from kubernetes.client.exceptions import ApiException


def load_kubernetes_config() -> None:
    try:
        config.load_incluster_config()
    except config.ConfigException:
        config.load_kube_config()


def scale_statefulset_to_zero(
    apps_api: AppsV1Api,
    namespace: str,
    statefulset_name: str,
    timeout_seconds: int,
    interval_seconds: int,
) -> int:
    try:
        statefulset = apps_api.read_namespaced_stateful_set(
            name=statefulset_name,
            namespace=namespace,
        )
    except ApiException as exc:
        raise RuntimeError(
            f"Failed to read StatefulSet {namespace}/{statefulset_name}: {exc}"
        ) from exc

    original_replicas = statefulset.spec.replicas or 0
    patch = {"spec": {"replicas": 0}}
    try:
        apps_api.patch_namespaced_stateful_set_scale(
            name=statefulset_name,
            namespace=namespace,
            body=patch,
        )
    except ApiException as exc:
        raise RuntimeError(
            f"Failed to scale StatefulSet {namespace}/{statefulset_name} to 0: {exc}"
        ) from exc

    deadline = time.time() + timeout_seconds
    while True:
        current = apps_api.read_namespaced_stateful_set(
            name=statefulset_name,
            namespace=namespace,
        )
        ready_replicas = current.status.ready_replicas or 0
        current_replicas = current.status.replicas or 0
        if ready_replicas == 0 and current_replicas == 0:
            return original_replicas

        if time.time() >= deadline:
            raise TimeoutError(
                "Timed out waiting for StatefulSet "
                f"{namespace}/{statefulset_name} to scale down to 0"
            )
        time.sleep(interval_seconds)


def scale_statefulset_to_replicas(
    apps_api: AppsV1Api,
    namespace: str,
    statefulset_name: str,
    replicas: int,
    timeout_seconds: int,
    interval_seconds: int,
) -> None:
    patch = {"spec": {"replicas": replicas}}
    try:
        apps_api.patch_namespaced_stateful_set_scale(
            name=statefulset_name,
            namespace=namespace,
            body=patch,
        )
    except ApiException as exc:
        raise RuntimeError(
            f"Failed to scale StatefulSet {namespace}/{statefulset_name} to {replicas}: {exc}"
        ) from exc

    deadline = time.time() + timeout_seconds
    while True:
        current = apps_api.read_namespaced_stateful_set(
            name=statefulset_name,
            namespace=namespace,
        )
        ready_replicas = current.status.ready_replicas or 0
        current_replicas = current.status.replicas or 0
        desired_replicas = current.spec.replicas or 0
        if (
            desired_replicas == replicas
            and current_replicas == replicas
            and ready_replicas == replicas
        ):
            return

        if time.time() >= deadline:
            raise TimeoutError(
                "Timed out waiting for StatefulSet "
                f"{namespace}/{statefulset_name} to scale back to {replicas}"
            )
        time.sleep(interval_seconds)


def run_command(command: list[str], extra_env: dict[str, str] | None = None) -> None:
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    subprocess.run(command, check=True, env=env)


def build_rclone_env(rclone_config_path: str) -> dict[str, str]:
    config_path = Path(rclone_config_path).expanduser()
    if not config_path.exists():
        raise FileNotFoundError(f"rclone config file does not exist: {config_path}")
    if not config_path.is_file():
        raise FileNotFoundError(f"rclone config path is not a file: {config_path}")
    return {"RCLONE_CONFIG": str(config_path)}


def build_restic_env(password_file: str | None) -> dict[str, str]:
    env: dict[str, str] = {}

    restic_password = os.getenv("RESTIC_PASSWORD")
    restic_password_file = password_file or os.getenv("RESTIC_PASSWORD_FILE")

    if restic_password:
        return env

    if restic_password_file:
        password_path = Path(restic_password_file)
        if not password_path.exists():
            raise FileNotFoundError(
                f"Restic password file does not exist: {password_path}"
            )
        if not password_path.is_file():
            raise FileNotFoundError(
                f"Restic password path is not a file: {password_path}"
            )
        env["RESTIC_PASSWORD_FILE"] = str(password_path)
        return env

    raise RuntimeError(
        "Restic password is not configured. Set RESTIC_PASSWORD, "
        "RESTIC_PASSWORD_FILE, or pass --password-file."
    )


def write_exclude_file(excludes: list[str]) -> str:
    tmp = tempfile.NamedTemporaryFile(mode="w", delete=False, encoding="utf-8")
    try:
        for item in excludes:
            tmp.write(f"{item}\n")
    finally:
        tmp.close()
    return tmp.name


def ensure_data_dir(path: str) -> None:
    data_dir = Path(path)
    if not data_dir.exists():
        raise FileNotFoundError(f"Backup data directory does not exist: {data_dir}")
    if not data_dir.is_dir():
        raise NotADirectoryError(f"Backup data path is not a directory: {data_dir}")


def run_restic_backup(
    repository: str,
    data_dir: str,
    backup_tag: str,
    host_tag: str,
    exclude_file: str,
    command_env: dict[str, str],
) -> None:
    # restic backup "$VW_DATA_DIR" \
    #         --tag vaultwarden \
    #         --tag "$HOST_TAG" \
    #         --exclude-file "$TMP_EXCLUDES"
    # backup <data_dir> to <repository> with backup and host tag
    command = [
        "restic",
        "-r",
        repository,
        "backup",
        data_dir,
        "--tag",
        backup_tag,
        "--tag",
        host_tag,
        "--exclude-file",
        exclude_file,
    ]
    run_command(command, extra_env=command_env)


def run_restic_forget(
    repository: str,
    backup_tag: str,
    command_env: dict[str, str],
) -> None:
    # keep the most recent 24 snapshots, regardless of time
    # # keep 1 snapshots per day for the last 30d
    # keep 1 snapshot per week for 8 weeks
    # keep 1 snapshot per month for 12 months
    command = [
        "restic",
        "-r",
        repository,
        "forget",
        "--tag",
        backup_tag,
        "--keep-last",
        "24",
        "--keep-daily",
        "30",
        "--keep-weekly",
        "8",
        "--keep-monthly",
        "12",
        "--prune",
    ]
    run_command(command, extra_env=command_env)


@click.command()
@click.option(
    "--namespace",
    envvar="VAULTWARDEN_NAMESPACE",
    default="vaultwarden",
    show_default=True,
    help="Kubernetes namespace that contains the StatefulSet.",
)
@click.option(
    "--statefulset",
    envvar="VAULTWARDEN_STATEFULSET",
    required=True,
    help="Name of the Vaultwarden StatefulSet to scale down and restore.",
)
@click.option(
    "--data-dir",
    envvar="VW_DATA_DIR",
    default="/data",
    show_default=True,
    help="Vaultwarden data directory that restic should back up.",
)
@click.option(
    "--restic-repository",
    envvar="RESTIC_REPOSITORY",
    required=True,
    help="Restic repository, for example rclone:remote-webdav:restic-backup.",
)
@click.option(
    "--host-tag",
    envvar="HOST_TAG",
    default="k8s-vaultwarden",
    show_default=True,
    help="Additional restic tag used to identify the source host or deployment.",
)
@click.option(
    "--backup-tag",
    envvar="BACKUP_TAG",
    default="vaultwarden",
    show_default=True,
    help="Primary restic tag for Vaultwarden backups.",
)
@click.option(
    "--password-file",
    envvar="RESTIC_PASSWORD_FILE",
    help="Path to a file containing the restic repository password.",
)
@click.option(
    "--rclone-config",
    envvar="RCLONE_CONFIG",
    default="~/.config/rclone/rclone.conf",
    show_default=True,
    help="Path to the rclone configuration file used by the restic rclone backend.",
)
@click.option(
    "--exclude",
    multiple=True,
    help="Path to exclude from the restic backup. Can be provided multiple times.",
)
@click.option(
    "--wait-timeout",
    envvar="SCALE_DOWN_TIMEOUT_SECONDS",
    default=300,
    show_default=True,
    type=int,
    help="Seconds to wait for scale-down and scale-up operations.",
)
@click.option(
    "--wait-interval",
    envvar="SCALE_DOWN_POLL_INTERVAL_SECONDS",
    default=5,
    show_default=True,
    type=int,
    help="Seconds between scale status checks.",
)
def main(
    namespace: str,
    statefulset: str,
    data_dir: str,
    restic_repository: str,
    host_tag: str,
    backup_tag: str,
    password_file: str | None,
    rclone_config: str,
    exclude: tuple[str, ...],
    wait_timeout: int,
    wait_interval: int,
) -> int:
    ensure_data_dir(data_dir)
    command_env = {}
    command_env.update(build_rclone_env(rclone_config))
    command_env.update(build_restic_env(password_file))
    load_kubernetes_config()
    apps_api = client.AppsV1Api()

    exclude_file = write_exclude_file(list(exclude))
    original_replicas: int | None = None
    try:
        original_replicas = scale_statefulset_to_zero(
            apps_api=apps_api,
            namespace=namespace,
            statefulset_name=statefulset,
            timeout_seconds=wait_timeout,
            interval_seconds=wait_interval,
        )
        run_restic_backup(
            repository=restic_repository,
            data_dir=data_dir,
            backup_tag=backup_tag,
            host_tag=host_tag,
            exclude_file=exclude_file,
            command_env=command_env,
        )
        run_restic_forget(
            repository=restic_repository,
            backup_tag=backup_tag,
            command_env=command_env,
        )
    finally:
        if original_replicas is not None:
            scale_statefulset_to_replicas(
                apps_api=apps_api,
                namespace=namespace,
                statefulset_name=statefulset,
                replicas=original_replicas,
                timeout_seconds=wait_timeout,
                interval_seconds=wait_interval,
            )
        try:
            os.unlink(exclude_file)
        except FileNotFoundError:
            pass

    return 0


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        print(
            f"Command failed with exit code {exc.returncode}: {exc.cmd}",
            file=sys.stderr,
        )
        raise SystemExit(exc.returncode) from exc
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1) from exc
