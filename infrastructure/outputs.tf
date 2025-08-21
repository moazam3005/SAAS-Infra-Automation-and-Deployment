output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "staging_instance_id" {
  value = module.ec2_staging.instance_id
}

output "prod_instance_id" {
  value = module.ec2_prod.instance_id
}
