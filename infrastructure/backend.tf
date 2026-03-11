terraform {
  backend "s3" {
    bucket         = "devendhar-terraform-state-bucket"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-lock"
    encrypt        = true
  }
}