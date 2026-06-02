# Conftest policy for Terraform tfplan validation
# Run: conftest test --policy policy/terraform tfplan.json

package main

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.after.publicly_accessible == true
    msg := sprintf("DENY: RDS instance '%s' is publicly accessible", [resource.address])
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.after.storage_encrypted != true
    msg := sprintf("DENY: RDS instance '%s' does not have storage encryption enabled", [resource.address])
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_elasticache_cluster"
    resource.change.after.transit_encryption_enabled != true
    msg := sprintf("DENY: ElastiCache cluster '%s' does not have transit encryption enabled", [resource.address])
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_security_group_rule"
    resource.change.after.cidr_blocks[_] == "0.0.0.0/0"
    resource.change.after.from_port == 22
    msg := sprintf("DENY: Security group rule '%s' allows SSH from 0.0.0.0/0", [resource.address])
}

warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.after.multi_az != true
    resource.change.after.environment == "prod"
    msg := sprintf("WARN: RDS instance '%s' in prod should have Multi-AZ enabled", [resource.address])
}

warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_elasticache_cluster"
    resource.change.after.at_rest_encryption_enabled != true
    msg := sprintf("WARN: ElastiCache cluster '%s' should have at-rest encryption enabled", [resource.address])
}
