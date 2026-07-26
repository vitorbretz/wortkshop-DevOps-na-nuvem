# Local Values

locals {
  account_id = var.aws_account_id != "" ? var.aws_account_id : data.aws_caller_identity.current.account_id

  # Bucket name following ADR-002 convention
  bucket_name = "${var.project_name}-${local.account_id}-terraform-state"

  # DynamoDB table name
  dynamodb_table_name = "${var.project_name}-terraform-state-lock"

  # Common tags
  common_tags = merge(
    var.additional_tags,
    {
      Stack = "remote-backend"
    }
  )
}
