terraform {
  backend "s3" {
    bucket         = "terraform-state-prod-2026"
    key            = "terraform-state-prod-2026/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock-2026"
  }
}