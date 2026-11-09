# Imported by every stack.
generate_hcl "_terramate_generated_common.tf" {
  content {
    locals {
      stack_name = terramate.stack.name
    }
  }
}
