# Day 2 — MCP Protocol: AI Agents with Tools

## Mục tiêu

Hiểu và triển khai Model Context Protocol (MCP) — standard protocol để kết nối AI agents với external tools (filesystem, Docker, K8s, Prometheus, AWS).

## MCP Architecture

```
┌──────────────┐         MCP Protocol          ┌──────────────────┐
│   Claude     │ ←────────────────────────────→ │   MCP Server 1   │
│   (Client)   │                               │   (filesystem)   │
└──────────────┘                                └──────────────────┘
       │                                                │
       ├────────────────────────────────────────────────┤
       │                  stdio / SSE                   │
       ├──────────────────┬─────────────────────────────┤
                       ┌──────────────────┐
                       │   MCP Server 2   │
                       │   (kubernetes)   │
                       └──────────────────┘
                       ┌──────────────────┐
                       │   MCP Server 3   │
                       │  (prometheus)    │
                       └──────────────────┘
                       ┌──────────────────┐
                       │   MCP Server 4   │
                       │    (docker)      │
                       └──────────────────┘
                       ┌──────────────────┐
                       │   MCP Server 5   │
                       │     (aws)        │
                       └──────────────────┘
```

## 5 MCP Servers

| Server | Package/Command | Version | Role |
|--------|----------------|---------|------|
| filesystem | `@modelcontextprotocol/server-filesystem` | 2026.1.14 | Read/write project dir only |
| docker | `docker mcp gateway run` | Docker Desktop ≥ 4.40 | Container inspect + logs |
| kubernetes | `kubernetes-mcp-server` | 0.0.62 | K8s read-only |
| prometheus | `@wkronmiller/prometheus-mcp-server` | 2.0.0 | Query metrics |
| aws | `uvx awslabs.aws-api-mcp-server` | 1.3.38 | AWS read-only |

## Security Model

### K8s — Least Privilege
- ServiceAccount: `mcp-readonly` trong namespace `insighthub`
- ClusterRole: read-only permissions (get, list, watch)
- ClusterRoleBinding: bind SA → CR

```bash
# Verify least privilege
kubectl auth can-i get pods --as=system:serviceaccount:insighthub:mcp-readonly  # yes
kubectl auth can-i delete pods --as=system:serviceaccount:insighthub:mcp-readonly  # no
```

### AWS — Read Only
- IAM profile: `mcp-readonly` với `ReadOnlyAccess` policy only
- No write permissions, no deletion

### Filesystem — Allow-list
- Chỉ cho phép đọc/ghi trong project directory
- Không truy cập `/`, `$HOME`

## Commands

```bash
# Verify MCP servers
claude mcp list                    # tất cả ✓ Connected
jq '.mcpServers | length' .mcp.json  # → 5

# Verify K8s least privilege
kubectl auth can-i get pods --as=system:serviceaccount:insighthub:mcp-readonly
kubectl auth can-i delete pods --as=system:serviceaccount:insighthub:mcp-readonly
```

## Artifacts

| Artifact | Description |
|----------|-------------|
| `.mcp.json` | MCP server configuration (5 servers) |
| `infra/k8s/mcp-readonly/` | K8s RBAC manifests |
| `infra/iam/` | AWS IAM policy for mcp-readonly |

## Key Concepts

- **MCP = Model Context Protocol** — open protocol cho AI ↔ tools
- **Transport**: stdio (local) hoặc SSE (remote)
- **Resources**: data expose từ server (files, DB rows)
- **Tools**: functions AI có thể gọi (kubectl, curl, read file)
- **Prompts**: reusable prompt templates
- **Security**: always least privilege, credentials qua env vars
