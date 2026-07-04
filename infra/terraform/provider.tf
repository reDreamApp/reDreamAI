provider "scaleway" {
  project_id = var.project_id
  region     = var.region

  # access_key / secret_key are intentionally NOT set here. Provide them via
  # SCW_ACCESS_KEY / SCW_SECRET_KEY env vars (or $HOME/.config/scw/config.yaml).
  # This repo has had a key-leak incident before — nothing that authenticates
  # to a provider belongs in a committed .tf or .tfvars file.
}
