variable "us_east_1_region" {
  description = "AWS region for the primary S3 bucket."
  type        = string
  default     = "us-east-1"
}

variable "us_east_2_region" {
  description = "AWS region for the replica S3 bucket."
  type        = string
  default     = "us-east-2"
}

variable "s3_primary_bucket_name" {
  description = "Globally unique name for the primary S3 bucket in us-east-1."
  type        = string
  default     = "vw-primary-bucket"
}

variable "s3_replica_bucket_name" {
  description = "Globally unique name for the replica S3 bucket in us-east-2."
  type        = string
  default     = "vw-replica-bucket"
}

variable "s3_access_user_name" {
  description = "IAM user name for Vaultwarden S3 access."
  type        = string
  default     = "vaultwarden-s3-user"
}
