locals {
  name_prefix = "${var.environment}-b2b"
  common_tags = {
    Environment = var.environment
    project     = "b2b-monolith"
  }
}
