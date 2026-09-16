# Measurement: the AWS build vs the GCP port

All timestamps UTC, 2026-09-15, from the same agent session (`docs/timestamps.txt` is the raw
record). Counts are `wc -l` over `*.tf` and `grep -c` over block headers. Wall time is
elapsed time in the session, including reading docs and writing READMEs, excluding the
up-front documentation verification (18:29–18:36) which served both clouds.

## Size

| | AWS | GCP | GCP / AWS |
|---|---|---|---|
| Stacks | 4 | 4 | 1.00 |
| `.tf` files | 30 | 27 | 0.90 |
| HCL lines | 950 | 823 | 0.87 |
| `resource` blocks | 32 | 18 | 0.56 |
| `data` blocks | 4 (2 remote_state, 2 policy documents) | 2 (remote_state) | |
| `variable` blocks | 13 | 14 | |
| `output` blocks | 17 | 17 | 1.00 |
| Pack files (`CLAUDE.md` + `.claude/**`) | 13 | 13 | 1.00 |
| `CLAUDE.md` lines | 82 | 84 (24 lines differ) | after the post-review alignment; 76 / 78 (15 differing) as first built |

Per stack:

| Stack | AWS files / lines / resources | GCP files / lines / resources |
|---|---|---|
| 00-remote-backend | 4 / 135 / 4 | 5 / 145 / 2 (+ services via count) |
| 01-networking | 10 / 263 / 13 | 7 / 182 / 4 |
| 02-eks / 02-gke | 8 / 293 / 8 | 7 / 239 / 4 |
| 03-data | 8 / 259 / 7 | 8 / 257 / 8 |

The resource count halves on GCP for structural reasons, not effort: S3 needs four
resources for what a GCS bucket does with arguments; AWS networking needs subnets, an IGW,
route tables and associations that GCP expresses as one subnet plus Cloud NAT.

## Time and iterations

| Phase | Start | End | Elapsed | validate runs (fails) |
|---|---|---|---|---|
| Docs verification, both clouds + hooks + MCP | 18:29 | 18:36 | ~7 min | — |
| **Act 1: AWS** (pack install, hooks, `.mcp.json`, 4 stacks, IAM policy) | 18:36:04 | 18:47:18 | **11 min 14 s** | 6 (1) |
| ├ 00-remote-backend | 18:38:54 | 18:40:41 | 1 min 47 s | 2 (1: `Invalid index`) |
| ├ 01-networking | 18:41:28 | 18:42:14 | 46 s | 1 (0) |
| ├ 02-eks | 18:43:23 | 18:44:18 | 55 s | 2 (0; second after moving data sources) |
| ├ 03-data | 18:44:54 | ~18:46:00 | ~1 min | 1 (0) |
| └ IAM plan-only policy + offline lint | ~18:46 | 18:47:18 | ~1 min | — |
| Act 1 verification (hook tests, remote_state fix) | 18:47:18 | 18:50:45 | 3 min 27 s | 2 (0) |
| **Act 2: GCP** (pack flavor, 4 stacks, IAM doc) | 18:50:45 | 18:57:55 | **7 min 10 s** | 5 (1 fmt) |
| ├ pack flavor (CLAUDE.md, 3 agents, 5 skills, hooks) | 18:50:45 | 18:54:48 | 4 min 03 s | — |
| ├ 00-remote-backend | 18:54:48 | 18:55:25 | 37 s | 1 (0) |
| ├ 01-networking | 18:55:25 | 18:56:14 | 49 s | 1 (0) |
| ├ 02-gke | 18:56:14 | 18:56:29 | 15 s | 2 (1: `fmt -check`) |
| ├ 03-data | 18:57:13 | 18:57:55 | 42 s | 1 (0) |
| └ IAM plan-only doc | (inside 03) | | | — |

Stack time has two honest bases, and they must not be mixed. The sum of the four stack
intervals excludes the gaps between stacks (reading the next spec, writing the README, the
odd re-validation); first start to last end includes them. `03-data` on AWS has no recorded
end timestamp in `timestamps.txt` (the IAM policy followed it without a marker), so its
interval is the ~1 min the log shows and both AWS figures carry a "~".

| Basis | AWS, 4 stacks | GCP, 4 stacks | GCP / AWS |
|---|---|---|---|
| Sum of the stack intervals (no gaps) | 1:47 + 0:46 + 0:55 + ~1:00 = **~4 min 28 s** | 0:37 + 0:49 + 0:15 + 0:42 = **2 min 23 s** | ~53% |
| First stack start to last stack end (with gaps) | 18:38:54 → ~18:46:00 = **~7 min 06 s** | 18:54:48 → 18:57:55 = **3 min 07 s** | ~44% |

On either basis the port ran at roughly half of the original's stack time, and the pack
flavor (4 min 03 s) was the largest single item of Act 2, more than the four GCP stacks
together.

Caveats, so the number is not oversold: Act 1 absorbed decisions Act 2 inherited for free
(fail-closed lookup, `workspace` on remote_state, POC flag comments, README shape); both
providers' docs were verified before Act 1; the agent had just written the AWS stacks and
the file layout was in context. A cold GCP port by a different session would sit between
the two numbers.

## Cost (monthly, 730 h, on-demand, before free tiers)

Infracost: **blocked**. `infracost` v2.1.0 is installed but its cached token is invalid
(`oauth2: invalid_grant`), and `infracost scan` waits on a browser login; not possible in
this session. Estimates below are by hand from official price lists, each line marked with
its source and confidence. Re-run `infracost auth login && infracost scan aws/terraform`
(and `gcp/terraform`) to replace them.

### AWS `us-east-1` (price list `pricing.us-east-1.amazonaws.com`, published 2026-09-10/11)

| Item | Unit price | Qty | Monthly | Source |
|---|---|---|---|---|
| EKS cluster (standard support) | $0.10 / h | 1 | $73.00 | AmazonEKS price list; EKS pricing page |
| EC2 `t4g.small` (Linux, on-demand) | $0.0168 / h | 2 | $24.53 | EC2 on-demand price JSON (pricing page source) |
| EBS gp3 (node root volumes) | $0.08 / GB-mo | 40 GB | $3.20 | AmazonEC2 price list |
| NAT gateway | $0.045 / h | 1 | $32.85 | AmazonEC2 price list; VPC pricing page |
| NAT data processing | $0.045 / GB | ~10 GB | ~$0.45 | same |
| Public IPv4 (NAT EIP) | $0.005 / h | 1 | $3.65 | AmazonVPC price list |
| RDS `db.t4g.micro` PostgreSQL Single-AZ | $0.016 / h | 1 | $11.68 | AmazonRDS price list |
| RDS gp3 storage | $0.115 / GB-mo | 20 GB | $2.30 | AmazonRDS price list |
| S3 (state + empty app bucket) | ~$0.023 / GB-mo | < 1 GB | ~$0.05 | — |
| **Total** | | | **≈ $152 / month** | all lines verified |

Guardrail: < $250 / month. Pass. Top drivers: EKS control plane (48%), NAT (24%), nodes (16%).

### GCP `us-central1`

| Item | Unit price | Qty | Monthly | Source / confidence |
|---|---|---|---|---|
| GKE Standard regional cluster fee | $0.10 / h | 1 | $73.00 | implied by the pricing page's "$74.40 monthly credit = one zonal/Autopilot cluster" (744 h); regional clusters are not covered by the credit. Verified indirectly |
| Compute `e2-small` | ~$0.0168 / h | 2 | ~$24.5 | **unverified** (pricing page is JS-rendered; number not retrievable this session) |
| Persistent Disk `pd-balanced` (node boot) | ~$0.10 / GB-mo | 40 GB | ~$4.00 | **unverified** |
| Cloud NAT gateway | $0.0014 / h per VM | 2 VMs | $2.04 | Cloud NAT pricing page (verified) |
| Cloud NAT data processing | $0.045 / GiB | ~10 GiB | ~$0.45 | Cloud NAT pricing page (verified) |
| Cloud SQL `db-f1-micro` PostgreSQL, Enterprise, zonal | ~$0.0105 / h | 1 | ~$7.7 | **unverified** |
| Cloud SQL storage PD SSD | $0.17 / GB-mo | 10 GB | $1.70 | Disk pricing example "200 GB SSD = $34/month" (verified) |
| Cloud SQL automated backups | ~$0.08 / GB-mo | < 5 GB | ~$0.40 | **unverified** |
| Cloud Storage (state + empty app bucket) | ~$0.020 / GB-mo | < 1 GB | ~$0.05 | — |
| **Total** | | | **≈ $114 / month** (≈ $37 of it unverified) | |

Guardrail: < $250 / month. Pass with margin even if the unverified lines doubled. Top
drivers: GKE fee (64%), nodes (21%). GCP lands ~25% under AWS here mostly because Cloud
NAT bills per VM-hour instead of per gateway-hour and there is no public IPv4 charge on
the NAT.

### Reading the two totals

Both floors are under the organisation's $250 POC guardrail and far under the $500
per-resource alert convention 13 sets. The comparison is not "GCP is cheaper": it is that a
single NAT gateway plus one public IP on AWS costs about what two GKE nodes cost on GCP,
and that a control plane is a control plane on both sides.
