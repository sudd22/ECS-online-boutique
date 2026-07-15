variable "environment" {
  type        = string
  description = "Target deployment environment"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}
variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnets to deploy RDS in"
}
variable "rds_sg_id" {
  type        = string
  description = "Security Group ID for RDS"
}
variable "db_name" {
  type        = string
  default     = "b2b_monolith_dev"
  description = "Postgres database name"
}
variable "db_username" {
  type        = string
  default     = "postgres"
  description = "Master database user name"
}
variable "instance_class" {
  type        = string
  default     = "db.t4g.micro"
  description = "RDS Instance class"
}
variable "engine_version" {
  type        = string
  default     = "15.18"
  description = "PostgreSQL engine version"
}
variable "allocated_storage" {
  type        = number
  default     = 20
  description = "RDS storage allocation (GB)"
}
variable "multi_az" {
  type        = bool
  default     = false
  description = "Enable multi-AZ failover configuration"
}
