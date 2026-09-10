variable "aws_region" {
  description = "AWS region for the MegaMart platform."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used in AWS resource names."
  type        = string
  default     = "megamart-shopcore"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "cluster_version" {
  description = "Amazon EKS Kubernetes version."
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "CIDR range for the EKS VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones used by the public and private subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.availability_zones) >= 3
    error_message = "At least three availability zones are required for the EKS data plane."
  }
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed EKS node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum number of worker nodes for Cluster Autoscaler."
  type        = number
  default     = 6
}

variable "alb_controller_namespace" {
  description = "Namespace for the AWS Load Balancer Controller service account."
  type        = string
  default     = "kube-system"
}

variable "alb_controller_service_account" {
  description = "Service account name used by the AWS Load Balancer Controller."
  type        = string
  default     = "aws-load-balancer-controller"
}