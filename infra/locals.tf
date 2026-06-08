locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    Owner       = "platform-team"
  })

  name_prefix = "insighthub-${var.environment}"
}
