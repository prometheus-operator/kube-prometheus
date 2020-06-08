terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "stash"

    workspaces {
      prefix = "prometheus-shared-services-"
    }
  }
}
