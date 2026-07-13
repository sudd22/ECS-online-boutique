terraform {
  backend "s3" {
    bucket         = "b2b-monolith-tf-state-i5b2dh96"
    key            = "persistent/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "b2b-monolith-tf-lock"
    encrypt        = true
  }
}
