module "shared" {
  source = "../../../../../modules/shared"
  name   = "${local.account_name}-${local.region}-${local.stack_name}"
}
