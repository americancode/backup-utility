# Backup utility

This repository contains a Kubernetes backup job and the container image it
runs. The job can back up MinIO/S3 buckets and PostgreSQL databases, then write
each archive to one or more configurable destinations:

- Azure Blob Storage or Azure Files, using the Azure CLI.
- Any S3-compatible object store, using the MinIO client (`mc`).
- A directory in the pod, normally backed by a PersistentVolumeClaim (PVC).

Every destination receives the same relative object path. For example, with
`BACKUP_PREFIX=k8s`, an archive may be written as:

```text
k8s/postgres/app/20260911T120000Z.dump
```

The destination is not a replacement for the temporary workspace. Archives are
created under `WORKDIR` and copied/uploaded as each backup completes. The
workspace is an `emptyDir`; the PVC destination is persistent storage.

## Deploying

Review and replace the example values in `k8s/configmap.yaml` and
`k8s/secret.yaml`, then apply the kustomization:

```sh
kubectl apply -k k8s/
```

The sample includes a `backup-pvc` requesting 100 GiB. Change `k8s/pvc.yaml` to
match the storage class and access mode available in the cluster. The job mounts
it at `/backup/pvc`, configured by `PVC_BACKUP_DIR`.

## Destination configuration

At least one destination must be configured. Destinations are independent, so
more than one can be enabled for redundancy.

### Azure

Set `AZURE_TARGET_TYPE` to `blob` or `file`, and configure the matching
container/share. Authentication supports one of these forms:

- `AZURE_STORAGE_CONNECTION_STRING`
- `AZURE_STORAGE_ACCOUNT` with `AZURE_STORAGE_KEY`
- `AZURE_STORAGE_ACCOUNT` with `AZURE_STORAGE_SAS_TOKEN`

`AZURE_CREATE_DESTINATION` defaults to `true` and creates the Blob container or
Azure Files share when needed. Set it to `false` to require the destination to
already exist.

### S3-compatible storage

Set `S3_TARGET_BUCKET` to enable the S3 destination. The endpoint and
credentials are required:

```yaml
S3_TARGET_ENDPOINT: https://s3.example.com
S3_TARGET_BUCKET: database-and-minio-backups
S3_TARGET_ALIAS: backup-s3       # optional; defaults to backup-s3
S3_TARGET_API: S3v4              # optional; defaults to S3v4
S3_TARGET_PATH: auto             # optional; defaults to auto
```

Put `S3_TARGET_ACCESS_KEY` and `S3_TARGET_SECRET_KEY` in the Secret. The bucket
must already exist; the job uploads objects below the configured bucket and
does not create it.

### PVC directory

Set `PVC_BACKUP_DIR` to enable local persistent copies. The directory must be a
writable path mounted into the container. The sample uses:

```yaml
PVC_BACKUP_DIR: /backup/pvc
```

The job creates parent directories beneath this path and preserves the same
prefix/timestamp layout used by the remote destinations. The PVC is not
automatically pruned, so configure storage capacity and retention according to
the backup schedule.

## Source and backup settings

MinIO source buckets are enabled with `MINIO_ENDPOINT` and selected with
`MINIO_BUCKETS`. Credentials are `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY`.
`MINIO_API` and `MINIO_PATH` default to `S3v4` and `auto`.

PostgreSQL can use the standard libpq variables (`PGHOST`, `PGPORT`, `PGUSER`,
`PGDATABASE`, and `PGPASSWORD`). Set `PGDATABASES` for multiple databases on one
server, or use `DATABASE_URL` for a single connection string.

`BACKUP_PREFIX` defaults to `backups`. `WORKDIR` defaults to `/backup/work` and
is always extended with the backup timestamp for isolation.

## Container user and certificates

The image runs as the non-root `backup` user (UID/GID 65532). The CA
certificate source and generated certificate directories are writable by that
user's group, allowing a mounted or copied `.crt` file to be followed by:

```sh
update-ca-certificates
```

The image also includes the Azure CLI, PostgreSQL client, MinIO client, and
common archive tools used by the job.
