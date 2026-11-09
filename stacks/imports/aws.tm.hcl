# Imported by the AWS stacks only.
generate_hcl "_terramate_generated_aws.tf" {
  content {
    locals {
      account_name = global.account_name
      region       = global.region
      cloud        = "aws"
    }
  }
}
