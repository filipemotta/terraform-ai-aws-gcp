# Named workspaces (sandbox/staging/production) store state as
# <prefix>/<workspace>.tfstate; without `workspace` this block would silently
# read the default workspace's state, which does not exist in this layout.
data "terraform_remote_state" "network" {
  backend   = "gcs"
  workspace = terraform.workspace

  config = {
    bucket = "atlas-us-central1-bucket-terraform-state"
    prefix = "networking"
  }
}

locals {
  network_id        = data.terraform_remote_state.network.outputs.network.id
  network_self_link = data.terraform_remote_state.network.outputs.network.self_link
}
