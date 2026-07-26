terraform {
  backend "s3" {
    bucket       = "togglemaster-tfstate-484338296618"
    key          = "togglemaster/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
