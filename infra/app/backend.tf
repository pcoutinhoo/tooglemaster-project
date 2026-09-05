terraform {
  backend "s3" {

    bucket       = "togglemaster-tfstate-676508800412"
    key          = "togglemaster/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
