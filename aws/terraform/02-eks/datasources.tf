# Named workspaces (sandbox/staging/production) store state under
# env:/<workspace>/<key>; without `workspace` this block would silently read
# the default workspace's state, which does not exist in this layout.
data "terraform_remote_state" "network" {
  backend   = "s3"
  workspace = terraform.workspace

  config = {
    bucket = "atlas-us-east-1-bucket-terraform-state"
    key    = "networking/networking.tfstate"
    region = "us-east-1"
  }
}

locals {
  vpc_id             = data.terraform_remote_state.network.outputs.vpc.id
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnets_ids
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnets_ids
}

# Trust policies for the two IAM roles in eks-iam-role.tf.
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
