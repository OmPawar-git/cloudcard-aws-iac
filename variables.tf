variable "aws_region" {
  default = "ap-south-1"
}

variable "project_name" {
  default = "MyApp"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "db_username" {
  default = "admin"
}

variable "db_password" {
  description = "RDS master password (set via terraform.tfvars, do not commit real password)"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "s3_bucket_name" {
  description = "Must be globally unique"
  default     = "myapp-static-assets-ompawar"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name for SSH access"
  default     = "myapp-key"
}
