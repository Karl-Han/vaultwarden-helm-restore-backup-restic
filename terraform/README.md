# Vaultwarden S3 Terraform

This directory contains Terraform only for Vaultwarden S3 storage in AWS. It creates:

- A primary private bucket in `us-east-1`
- A replica private bucket in `us-east-2`
- Cross-region replication from the primary bucket to the replica bucket
- An IAM role and policy for S3 replication
- An IAM user policy and access key for application access to the primary bucket

## Files and How to Read Them

### `provider.tf`

Read this file first. It tells Terraform:

- which AWS provider version to use
- that the default provider targets `var.us_east_1_region`
- that a second aliased provider named `aws.us_east_2` targets `var.us_east_2_region`

When you see `provider = aws.us_east_2` in another file, that resource is created in the secondary region.

### `variables.tf`

Read this file second. It defines the inputs you are expected to set:

- `us_east_1_region`: source bucket region
- `us_east_2_region`: destination bucket region
- `s3_primary_bucket_name`: bucket that Vaultwarden writes to
- `s3_replica_bucket_name`: bucket that receives replicated objects
- `s3_access_user_name`: IAM user name for access key creation

Bucket names must be globally unique across AWS.

### `s3.tf`

This is the main infrastructure file.

- `aws_s3_bucket.primary` creates the source bucket in `us-east-1`
- `aws_s3_bucket.replica` creates the destination bucket in `us-east-2`
- each bucket has versioning enabled because S3 replication requires it
- each bucket has `aws_s3_bucket_public_access_block` so the buckets are not publicly accessible
- `aws_s3_bucket_replication_configuration.primary_to_replica` connects the primary bucket to the replica bucket

If you want to understand the flow, read this file top to bottom in this order:

1. primary bucket
2. primary bucket protection and versioning
3. replica bucket
4. replica bucket protection and versioning
5. replication configuration

### `iam.tf`

This file contains all IAM pieces.

- `aws_iam_role.s3_replication` is assumed by S3 itself
- `aws_iam_role_policy.s3_replication` gives S3 permission to read object versions from the primary bucket and write them to the replica bucket
- `aws_iam_user.s3_access` is the application user
- `aws_iam_user_policy.s3_access` allows the application to list the primary bucket and read, write, and delete objects in it
- `aws_iam_access_key.s3_access` generates the access key ID and secret access key

Read the policy statements by matching each `Resource` to either:

- the bucket itself, for actions like `ListBucket`
- the objects inside the bucket, for actions like `GetObject` and `PutObject`

### `outputs.tf`

Read this after the resources. It shows what Terraform will return after `apply`.

- bucket names
- replication role ARN
- access key ID
- secret access key

The access key outputs are marked `sensitive`, so Terraform hides them in normal CLI output unless you query them directly.

### `terraform.tfvars.example`

Use this file as your template for local values.

1. copy it to `terraform.tfvars`
2. replace both bucket names with globally unique names
3. optionally change the IAM user name

## How to Use

From this directory:

```bash
terraform init
terraform fmt
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## How to Read the Outputs

After `terraform apply`, retrieve the sensitive credentials with:

```bash
terraform output s3_access_key_id
terraform output -raw s3_secret_access_key
```

Use:

- `s3_primary_bucket_name` as the application bucket
- `s3_access_key_id` and `s3_secret_access_key` for programmatic access
- `s3_replica_bucket_name` to confirm the replication target
