resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.eks.node_group.name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = local.private_subnet_ids
  instance_types  = var.eks.node_group.instance_types
  ami_type        = var.eks.node_group.ami_type
  capacity_type   = var.eks.node_group.capacity_type
  disk_size       = var.eks.node_group.disk_size

  scaling_config {
    desired_size = var.eks.node_group.desired_size
    min_size     = var.eks.node_group.min_size
    max_size     = var.eks.node_group.max_size
  }

  tags = {
    Name = var.eks.node_group.name
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}
