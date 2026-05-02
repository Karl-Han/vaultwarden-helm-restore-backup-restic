output "us_east_1_region" {
  description = "Primary AWS region for the source bucket."
  value       = var.us_east_1_region
}

output "us_east_2_region" {
  description = "Secondary AWS region for the replica bucket."
  value       = var.us_east_2_region
}

output "s3_primary_bucket_name" {
  description = "Name of the primary S3 bucket."
  value       = aws_s3_bucket.primary.id
}

output "s3_replica_bucket_name" {
  description = "Name of the replica S3 bucket."
  value       = aws_s3_bucket.replica.id
}

output "s3_replication_role_arn" {
  description = "ARN of the IAM role used by S3 replication."
  value       = aws_iam_role.s3_replication.arn
}

output "s3_access_key_id" {
  description = "Access key ID for the Vaultwarden S3 IAM user."
  value       = aws_iam_access_key.s3_access.id
  sensitive   = true
}

output "s3_secret_access_key" {
  description = "Secret access key for the Vaultwarden S3 IAM user."
  value       = aws_iam_access_key.s3_access.secret
  sensitive   = true
}
