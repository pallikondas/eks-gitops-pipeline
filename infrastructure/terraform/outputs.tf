output "cluster_name" {
  description = "EKS cluster name used by later GitOps bootstrap steps."
  value       = module.eks.cluster_name
}

output "aws_region" {
  description = "AWS region containing the platform."
  value       = var.aws_region
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC hosting the EKS cluster."
  value       = module.vpc.vpc_id
}

output "order_service_role_arn" {
  description = "IRSA role ARN for the Order Service Kubernetes ServiceAccount."
  value       = aws_iam_role.order_service.arn
}

output "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN for the Cluster Autoscaler ServiceAccount."
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller service account."
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "orders_table_name" {
  description = "DynamoDB table name for order persistence."
  value       = aws_dynamodb_table.orders.name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs for the application services."
  value = {
    order_service   = aws_ecr_repository.order_service.repository_url
    catalog_service = aws_ecr_repository.catalog_service.repository_url
  }
}