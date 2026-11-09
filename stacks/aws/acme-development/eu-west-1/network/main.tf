resource "terraform_data" "this" {
  input = "${local.account_name}-${local.region}-${local.stack_name}-v2"
}
