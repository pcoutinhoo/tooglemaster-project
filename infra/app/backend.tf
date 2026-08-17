terraform {
  backend "s3" {
    
    bucket       = "togglemaster-tfstate-445903040232"

    key          = "togglemaster/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
