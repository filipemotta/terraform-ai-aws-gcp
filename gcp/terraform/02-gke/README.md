# 02-gke

## Purpose
The Kubernetes floor: a regional GKE Standard cluster with private nodes on the subnet of 01-networking, one small node pool and a dedicated node service account.

## Provisions
- `google_service_account.node` + `google_project_iam_member.node[*]`
- `google_container_cluster.this` (VPC-native, Dataplane V2, private nodes, public endpoint, Workload Identity, REGULAR channel)
- `google_container_node_pool.this` (e2-small, 1 per zone x 2 zones = 2 nodes, Shielded, GKE metadata server)

## Consumes (from upstream stacks)
- `01-networking` via `data.terraform_remote_state.network`: `network`, `subnetwork`, `pods_range_name`, `services_range_name`

## Provides (for downstream stacks)
- `cluster_name`, `gke_cluster` (sensitive) ... for kubeconfig and any future add-ons stack
- `node_pool`, `node_service_account_email`

## What changed from the AWS stack (resource by resource)
| AWS (02-eks)                                              | GCP (02-gke)                                                        |
|-----------------------------------------------------------|---------------------------------------------------------------------|
| `aws_iam_role.cluster` + policy attachments               | none: the control plane runs under a Google-managed service agent   |
| `aws_iam_role.node` + 3 policy attachments                | `google_service_account.node` + `google_project_iam_member.node[4]` |
| `aws_eks_cluster.this` (version pinned)                   | `google_container_cluster.this` (release channel instead of a pin)  |
| `vpc_config.subnet_ids` (private subnets)                 | `network` + `subnetwork` + `ip_allocation_policy` secondary ranges  |
| `access_config` authentication_mode API + access entry    | none: GKE authorizes through project IAM; no cluster-level entry    |
| `aws_eks_node_group.this` (t4g.small x2, `desired_size`)  | `google_container_node_pool.this` (e2-small, `node_count` per zone) |
| `ami_type = AL2023_ARM_64_STANDARD`                       | Container-Optimized OS is the default image; no AMI choice          |
| IRSA / Pod Identity (not configured)                      | `workload_identity_config` + `GKE_METADATA` on the pool             |
| `depends_on` policy attachments                           | none needed                                                         |

## Notes
- Cost drivers: cluster management fee + 2 x e2-small + 2 x 20 GB pd-balanced. Nothing else billable in this stack.
- `node_locations` lists 2 zones with `node_count = 1` each, matching the AWS pair of AZs and 2 nodes.
