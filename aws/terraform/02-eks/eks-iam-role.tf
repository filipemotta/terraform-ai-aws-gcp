# Two roles: one the control plane assumes (eks.amazonaws.com), one the node
# EC2 instances assume (ec2.amazonaws.com). Trust policies are data sources in
# datasources.tf; managed policy lists come from the domain object.

resource "aws_iam_role" "cluster" {
  name               = var.eks.cluster_iam_role_name
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = {
    Name = var.eks.cluster_iam_role_name
  }
}

resource "aws_iam_role_policy_attachment" "cluster" {
  count      = length(var.eks.cluster_policy_arns)
  role       = aws_iam_role.cluster.name
  policy_arn = var.eks.cluster_policy_arns[count.index]
}

resource "aws_iam_role" "node" {
  name               = var.eks.node_iam_role_name
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json

  tags = {
    Name = var.eks.node_iam_role_name
  }
}

resource "aws_iam_role_policy_attachment" "node" {
  count      = length(var.eks.node_policy_arns)
  role       = aws_iam_role.node.name
  policy_arn = var.eks.node_policy_arns[count.index]
}
