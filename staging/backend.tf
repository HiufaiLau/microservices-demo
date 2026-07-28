terraform {
  backend "s3" {
    bucket         = "sockshop-terraform-state-414772274298"
    key            = "staging/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "sockshop-terraform-locks"
    encrypt        = true
  }
}
