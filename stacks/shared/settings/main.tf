locals {
  settings = jsondecode(file("../../../config/settings.json"))
}

resource "terraform_data" "this" {
  input = "${local.stack_name}-${local.settings.replicas}"
}
