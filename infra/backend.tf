# Terraform state backend configuration
# Note: S3 bucket and DynamoDB table should be created separately

terraform {
  backend "s3" {
    # These values should be provided via -backend-config flag or backend config file
    # Example: terraform init -backend-config="bucket=insighthub-terraform-state" \
    #                        -backend-config="key=insighthub/terraform.tfstate" \
    #                        -backend-config="region=us-east-1" \
    #                        -backend-config="dynamodb_table=terraform-locks" \
    #                        -backend-config="encrypt=true"

    # For development, these can be set as defaults
    bucket         = "insighthub-terraform-state"
    key            = "insighthub/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
