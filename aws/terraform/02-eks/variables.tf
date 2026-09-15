variable "tags" {
  description = "Global tags injected by the provider default_tags block. Resources only add Name."
  type        = map(string)

  default = {
    "Project"   = "atlas"
    "Env"       = "sandbox"
    "region"    = "us-east-1"
    "ManagedBy" = "terraform"
  }
}
variable "assume_role" {
  description = "Region and fallback role for the provider. role_arn is used for any workspace not mapped in main.tf (fail closed: plan-only)."
  type = object({
    role_arn = string
    region   = string
  })

  default = {
    role_arn = "arn:aws:iam::123456789012:role/terraform-plan-readonly"
    region   = "us-east-1"
  }
}

variable "eks" {
  description = "Cluster, node group and access configuration. admin_principal_arn is the only IAM principal that gets Kubernetes cluster-admin."
  type = object({
    cluster_name            = string
    cluster_version         = string
    cluster_iam_role_name   = string
    cluster_policy_arns     = list(string)
    node_iam_role_name      = string
    node_policy_arns        = list(string)
    authentication_mode     = string
    endpoint_public_access  = bool
    endpoint_private_access = bool
    admin_principal_arn     = string
    admin_access_policy_arn = string
    node_group = object({
      name           = string
      instance_types = list(string)
      ami_type       = string
      capacity_type  = string
      disk_size      = number
      desired_size   = number
      min_size       = number
      max_size       = number
    })
  })

  default = {
    cluster_name          = "eks-cluster-atlas"
    cluster_version       = "1.36"
    cluster_iam_role_name = "eks-cluster-iam-role-atlas"
    cluster_policy_arns = [
      "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    ]
    node_iam_role_name = "eks-node-iam-role-atlas"
    node_policy_arns = [
      "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
      "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
      "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    ]
    authentication_mode     = "API"
    endpoint_public_access  = true
    endpoint_private_access = true
    admin_principal_arn     = "arn:aws:iam::123456789012:role/platform-admin"
    admin_access_policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    node_group = {
      name           = "eks-node-group-atlas"
      instance_types = ["t4g.small"]
      ami_type       = "AL2023_ARM_64_STANDARD"
      capacity_type  = "ON_DEMAND"
      disk_size      = 20
      desired_size   = 2
      min_size       = 1
      max_size       = 2
    }
  }
}
