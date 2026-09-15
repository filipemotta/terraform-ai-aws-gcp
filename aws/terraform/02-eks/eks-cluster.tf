resource "aws_eks_cluster" "this" {
  name     = var.eks.cluster_name
  version  = var.eks.cluster_version
  role_arn = aws_iam_role.cluster.arn

  access_config {
    authentication_mode                         = var.eks.authentication_mode
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids              = local.private_subnet_ids
    endpoint_public_access  = var.eks.endpoint_public_access
    endpoint_private_access = var.eks.endpoint_private_access
  }

  tags = {
    Name = var.eks.cluster_name
  }

  # The role must carry its policies before EKS uses it, and must keep them
  # until the cluster is gone (otherwise EKS cannot clean up its ENIs/SGs).
  depends_on = [aws_iam_role_policy_attachment.cluster]
}
