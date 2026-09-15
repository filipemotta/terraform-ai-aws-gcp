output "eks_cluster" {
  description = "The EKS cluster object (endpoint, certificate_authority, identity, vpc_config)."
  value       = aws_eks_cluster.this
}

output "cluster_name" {
  description = "Cluster name, for kubeconfig generation (aws eks update-kubeconfig --name)."
  value       = aws_eks_cluster.this.name
}

output "node_group" {
  description = "The managed node group object."
  value       = aws_eks_node_group.this
}

output "cluster_iam_role_arn" {
  description = "ARN of the control plane IAM role."
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "ARN of the node IAM role. A later add-ons stack may attach policies to it."
  value       = aws_iam_role.node.arn
}
