# MCP setup: what the pack's loop needs before the first prompt

The pack's tooling strategy is a loop: **schema → write → validate → plan → cost → review →
human apply**. Three of those steps call tools that are not part of Claude Code itself.
Install them once; the repository ships `.mcp.json` files so a fresh clone already knows
about the servers.

| Step in the loop            | Tool                              | Why it exists                                                                 |
|-----------------------------|-----------------------------------|-------------------------------------------------------------------------------|
| schema (anti-hallucination) | **Terraform MCP** (HashiCorp)     | `search_providers` + `get_provider_details` return the provider's own resource docs for the pinned version. No attribute is written from memory. |
| docs (syntax, backends)     | **Context7**                      | `resolve-library-id` + `query-docs` for Terraform language docs and provider guides when the registry doc is not enough. |
| cloud (read-only checks)    | **AWS MCP** (`aws-core` plugin) / **gcloud MCP** | Read account facts the plan needs (regions, quotas, existing resources) without leaving the session. |
| cost                        | **Infracost plugin**              | `/infracost:scan` after `terraform plan`; the guide's $500/month gate.        |

Everything below was verified on 2026-09-15 against the official sources linked.

## 1. Project scope: the shipped `.mcp.json`

Claude Code reads a project-scoped `.mcp.json` at the repository root
(format: https://code.claude.com/docs/en/mcp). Both `aws/` and `gcp/` ship one:

```json
{
  "mcpServers": {
    "terraform": {
      "type": "stdio",
      "command": "docker",
      "args": ["run", "-i", "--rm", "hashicorp/terraform-mcp-server"]
    },
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
```

`gcp/.mcp.json` adds:

```json
    "gcloud": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@google-cloud/gcloud-mcp"]
    }
```

Prerequisites: Docker (Terraform MCP image `hashicorp/terraform-mcp-server`, v1.3.0 at
the time of writing), Node.js 20+ (`npx`), and for gcloud MCP (v0.5.3) an authenticated
`gcloud` CLI. On first start Claude Code asks you to trust the project's servers.

## 2. User scope: the same servers for every repository

```bash
# Terraform MCP (official install command from github.com/hashicorp/terraform-mcp-server)
claude mcp add terraform -s user -t stdio -- docker run -i --rm hashicorp/terraform-mcp-server

# Context7 (github.com/upstash/context7)
claude mcp add context7 -s user -t stdio -- npx -y @upstash/context7-mcp

# gcloud MCP (github.com/googleapis/gcloud-mcp), GCP repositories only
claude mcp add gcloud -s user -t stdio -- npx -y @google-cloud/gcloud-mcp
```

`-s user` stores the server in your user config; `-t stdio` is the transport; everything
after `--` is the server command.

## 3. Plugins: AWS, Infracost, Context7 (alternative)

```bash
# AWS: official plugin from aws/agent-toolkit-for-aws (MCP proxy + skills). Needs `uv`.
/plugin install aws-core@claude-plugins-official
# if the official marketplace is not available in your install:
/plugin marketplace add aws/agent-toolkit-for-aws

# Infracost (www.infracost.io/docs/ai_editor_plugins/ai_skills/)
claude plugin marketplace add infracost/agent-skills
claude plugin install infracost@infracost
#   exposes /infracost:scan, /infracost:price-lookup, /infracost:iac-generation
#   first use prompts for dependencies and account authentication (free account)

# Context7 is also available as a plugin instead of an MCP entry:
/plugin install context7@claude-plugins-official
```

AWS credentials stay local and are only used for API calls the AWS MCP makes on your
behalf; documentation searches need none. For gcloud MCP the permissions are those of the
authenticated `gcloud` account; the README recommends service account impersonation with
narrow roles, which is exactly the plan-only / apply pair this repository defines.

## 4. Verify

```bash
claude mcp list
```

Every server should show `✔ Connected`. `⏸ Pending approval` means the project-scoped
server is waiting for the trust dialog; `✘ Failed to connect` usually means Docker is not
running (terraform) or `npx` cannot download the package (context7, gcloud).

## 5. What the pack does when a server is down

The loop degrades, it does not skip:

- **Terraform MCP down**: the agent fetches the provider documentation for the pinned
  version from the registry source instead (for `hashicorp/aws` v6.64.0 the resource docs
  live at `website/docs/r/<resource>.html.markdown` in the provider repository, which is
  what `get_provider_details` returns). It never writes a resource block from memory.
- **Context7 down**: `developer.hashicorp.com/terraform` via web fetch.
- **AWS / gcloud MCP down**: the agent asks the human for the account facts it needs, or
  reads them from `outputs.tf` of an upstream stack. It does not guess.
- **Infracost not authenticated**: the cost step reports "blocked", and the estimate is
  built by hand from the official price lists, marked as such (see `docs/measurement.md`).

This repository was built in exactly that degraded mode for the schema step: the Terraform
MCP was configured but not exposed to the build session, so every resource argument was
checked against the provider docs at the pinned tag, and the fallback is recorded in
`docs/build-log-aws.md`.

## A note on tool names

The pack as the guide ships it names `get_schema`, `terraform_init`, `terraform_validate`
and `terraform_plan` as Terraform MCP tools. The official server (v1.3.0) exposes registry
tools (`search_providers`, `get_provider_details`, `get_provider_capabilities`,
`get_latest_provider_version`, `search_modules`, `get_module_details`, `search_policies`,
...) and HCP Terraform workspace/run tools; `init`, `validate` and `plan` run through the
Bash tool, and the schema step is `search_providers` → `get_provider_details`. The
behaviour the pack asks for is the same; the names were not. The `CLAUDE.md` of each flavor
in this repository names the real tools (see its Tooling Strategy section); treat the
guide's names as the intent, not the API.
