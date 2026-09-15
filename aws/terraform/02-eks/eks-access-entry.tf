# Cluster creator admin bootstrap is off; the only cluster-admin is the
# principal below. Terraform's own role never touches Kubernetes objects.

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.eks.admin_principal_arn
  type          = "STANDARD"

  tags = {
    Name = "eks-access-entry-admin-atlas"
  }
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = var.eks.admin_access_policy_arn

  access_scope {
    type = "cluster"
  }
}
