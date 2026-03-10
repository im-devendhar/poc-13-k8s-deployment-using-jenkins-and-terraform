
# VPC & Subnets
output "vpc_id" {
  description = "VPC ID for the EKS environment"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (typically for ALB/NLB)"
  value = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]
}

output "private_subnet_ids" {
  description = "Private subnet IDs (used for EKS node groups)"
  value = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
}

# Route tables (optional but handy for troubleshooting)
output "public_route_table_id" {
  description = "Route table ID associated with public subnets"
  value       = aws_route_table.public_rt.id
}

output "private_route_table_id" {
  description = "Route table ID associated with private subnets"
  value       = aws_route_table.private_rt.id
}

# Internet/NAT (optional visibility)
output "internet_gateway_id" {
  description = "Internet Gateway ID for public egress"
  value       = aws_internet_gateway.igw.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID used by private subnets for outbound internet"
  value       = aws_nat_gateway.nat_gw.id
}

output "nat_eip_allocation_id" {
  description = "Elastic IP allocation ID attached to the NAT Gateway"
  value       = aws_eip.nat_eip.id
}


# EKS Cluster

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.eks.name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.eks.arn
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.eks.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded EKS cluster CA data"
  value       = aws_eks_cluster.eks.certificate_authority[0].data
  sensitive   = true
}

# A handy command you can copy to set kubeconfig on your machine
output "kubeconfig_update_command" {
  description = "Run this to merge the EKS cluster context into your ~/.kube/config"
  value = "aws eks update-kubeconfig --name ${aws_eks_cluster.eks.name} --region ${var.region}"
}


# EKS Node Group

output "node_group_name" {
  description = "Managed node group name"
  value       = aws_eks_node_group.node_group.node_group_name
}

output "node_group_arn" {
  description = "Managed node group ARN"
  value       = aws_eks_node_group.node_group.arn
}

output "node_group_status" {
  description = "Managed node group current status"
  value       = aws_eks_node_group.node_group.status
}


# IAM Roles (Cluster & Nodes)

output "eks_cluster_role_name" {
  description = "IAM role name used by EKS control plane"
  value       = aws_iam_role.eks_cluster_role.name
}

output "eks_cluster_role_arn" {
  description = "IAM role ARN used by EKS control plane"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_role_name" {
  description = "IAM role name used by EKS worker nodes"
  value       = aws_iam_role.eks_node_role.name
}

output "eks_node_role_arn" {
  description = "IAM role ARN used by EKS worker nodes"
  value       = aws_iam_role.eks_node_role.arn
}