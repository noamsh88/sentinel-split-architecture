terraform {
  backend "s3" {
    bucket         = "sentinel-terraform-state"
    key            = "sentinel-split-architecture/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "sentinel-terraform-locks"
  }
}
