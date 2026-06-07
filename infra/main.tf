module "database" {
  source = "./modules/database"

  environment        = var.environment
  aws_region         = var.aws_region
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  enable_encryption  = var.enable_encryption
  enable_multi_az    = var.enable_multi_az
  instance_class     = var.rds_instance_class
  allocated_storage  = var.rds_allocated_storage
  database_name      = var.rds_database_name
  master_username    = var.rds_master_username
  kms_key_arn        = var.kms_key_arn
  eks_cluster_name   = var.cluster_name
  tags               = local.common_tags
}

module "cache" {
  source = "./modules/cache"

  environment        = var.environment
  aws_region         = var.aws_region
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  enable_encryption  = var.enable_encryption
  enable_multi_az    = var.enable_multi_az
  node_type          = var.redis_node_type
  num_cache_nodes    = var.redis_num_cache_nodes
  kms_key_arn        = var.kms_key_arn
  eks_nodes_sg_id    = module.networking.eks_nodes_sg_id
  tags               = local.common_tags

  depends_on = [module.database]
}

module "irsa" {
  source = "./modules/irsa"

  environment      = var.environment
  cluster_name     = var.cluster_name
  namespace_name   = local.name_prefix
  rds_endpoint     = module.database.endpoint
  redis_endpoint   = module.cache.endpoint
  rds_secret_arn   = module.database.credentials_secret_arn
  redis_secret_arn = module.cache.connection_secret_arn
  tags             = local.common_tags
}

module "networking" {
  source = "./modules/networking"

  environment  = var.environment
  vpc_id       = var.vpc_id
  cluster_name = var.cluster_name
  rds_sg_id    = module.database.security_group_id
  redis_sg_id  = module.cache.security_group_id
  tags         = local.common_tags
}
