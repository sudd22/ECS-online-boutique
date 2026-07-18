module "vpc" {
  source             = "../../modules/vpc"
  env                = var.environment
  deploy_nat_gateway = var.deploy_nat_gateway
}

module "rds" {
  source             = "../../modules/rds"
  env                = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  rds_sg_id          = module.vpc.rds_sg
}

module "alb" {
  source            = "../../modules/alb"
  env               = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg            = module.vpc.alb_sg
}

module "waf" {
  source       = "../../modules/waf"
  env          = var.environment
  resource_arn = module.alb.alb_arn
}

module "sqs" {
  source                = "../../modules/sqs"
  env                   = var.environment
  private_subnet_ids    = module.vpc.private_subnet_ids
  consumer_lambda_sg_id = module.vpc.lambda_sg
  db_host               = module.rds.db_host
  db_username           = "postgres"
  db_name               = "b2b_monolith_dev"
  db_secret_arn         = module.rds.db_secret_arn
  ecr_url               = "774667856934.dkr.ecr.eu-west-2.amazonaws.com/b2b-monolith-app"
}

module "ecs" {
  source                  = "../../modules/ecs"
  env                     = var.environment
  region                  = var.region
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  ecs_tasks_sg_id         = module.vpc.ecs_tasks_sg
  target_group_arn        = module.alb.target_group_arn
  ecr_url                 = "774667856934.dkr.ecr.eu-west-2.amazonaws.com/b2b-monolith-app"
  db_host                 = module.rds.db_host
  db_username             = "postgres"
  db_name                 = "b2b_monolith_dev"
  db_secret_arn           = module.rds.db_secret_arn
  notifications_queue_url = module.sqs.notifications_queue_url
  notifications_queue_arn = module.sqs.notifications_queue_arn
  desired_count           = 2
}

