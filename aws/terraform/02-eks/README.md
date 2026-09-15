# 02-eks

## Purpose
The Kubernetes floor: an EKS control plane on the private subnets of 01-networking, one small managed node group and the IAM roles both need.

## Provisions
- `aws_iam_role.cluster` + `aws_iam_role_policy_attachment.cluster[*]`
- `aws_iam_role.node` + `aws_iam_role_policy_attachment.node[*]`
- `aws_eks_cluster.this` (authentication_mode API, creator admin bootstrap disabled)
- `aws_eks_node_group.this` (t4g.small x2, AL2023 ARM64, on-demand)
- `aws_eks_access_entry.admin` + `aws_eks_access_policy_association.admin` (AmazonEKSClusterAdminPolicy, cluster scope)

## Consumes (from upstream stacks)
- `01-networking` via `data.terraform_remote_state.network`: `vpc`, `public_subnets_ids`, `private_subnets_ids`

## Provides (for downstream stacks)
- `eks_cluster`, `cluster_name` ... for kubeconfig and any future add-ons stack
- `node_group`, `cluster_iam_role_arn`, `node_iam_role_arn`

## Notes
- Cost drivers: control plane hour rate + 2 x t4g.small. Nothing else billable in this stack.
- `bootstrap_cluster_creator_admin_permissions = false`: the role running apply gets no Kubernetes access; only `admin_principal_arn` does.
