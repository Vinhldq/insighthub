# Day 2 Debug Session Log — InsightHub MCP Protocol

## Case Study 1: Investigating Unhealthy 'web' Container

**Problem Statement**: User reports the web interface is slow or unreachable. `docker ps` shows `insighthub-web-1` status as `unhealthy`.

**Tools Used via MCP**:
- **Docker MCP**: Inspect container state and logs.
- **Filesystem MCP**: Read Dockerfile configuration.

### Step 1: Perceive — Check Container Status
- Action: `docker ps` via Docker MCP `list_containers`
- Observation: `insighthub-web-1` is `unhealthy`.

### Step 2: Reason — Diagnose Root Cause
- Action: `docker inspect insighthub-web-1` via Docker MCP `inspect_container`
- Observation: healthcheck log shows `wget localhost:3000` connecting to `[::1]:3000` (IPv6) but Next.js listens on IPv4 `0.0.0.0`.
- Inference: `localhost` resolves to IPv6 `::1` first, causing connection refused.

### Step 3: Act — Fix Healthcheck
- Action: Read `web/Dockerfile` via Filesystem MCP, confirm healthcheck uses `localhost`.
- Action: Change `http://localhost:3000/api/health` → `http://127.0.0.1:3000/api/health`.

### Step 4: Observe — Verify Fix
- Result: `insighthub-web-1` becomes `healthy`.

---

## Case Study 2: MCP Configuration — Version Pinning & Security

**Problem**: Initial `.mcp.json` had wrong versions and missing security flags vs CLAUDE.md spec.

### Diagnosis
| Server | Old (wrong) | Target (CLAUDE.md) |
|--------|-------------|-------------------|
| filesystem | `@0.6.2` | `@2026.1.14` |
| docker | `@modelcontextprotocol/server-docker@0.5.0` (npx) | `docker mcp gateway run` |
| kubernetes | `@0.7.0`, no `--read-only` | `@0.0.62`, `--read-only` |
| prometheus | `@0.5.0` (wrong package) | `@2.0.0` (correct package) |
| aws | `@0.5.0` (npx) | `@1.3.38` (uvx) |

### Fixes Applied
1. Pinned all 5 versions to exact numbers (no `@latest`).
2. Added `--read-only` flag to kubernetes server.
3. Changed docker command from `npx` package to `docker mcp gateway run`.
4. Changed aws command from `npx` to `uvx`.
5. Kept `AWS_PROFILE: mcp-readonly` env var for least-privilege.

### Verification
```bash
jq '.mcpServers | length' .mcp.json        # → 5
jq '.mcpServers[].args[]?' .mcp.json | grep -qE '@latest|@main'  # → no match
claude mcp list                              # → all Connected
```

---

## Case Study 3: K8s Least-Privilege RBAC

**Problem**: MCP kubernetes server needs read-only cluster access.

### Action
Created 4 YAML manifests at `infra/k8s/mcp-readonly/`:
- `namespace.yaml`: `insighthub` namespace
- `serviceaccount.yaml`: `mcp-readonly` SA
- `clusterrole.yaml`: GET/LIST/WATCH on pods, services, nodes, deployments, replicasets, ingresses, networkpolicies
- `clusterrolebinding.yaml`: binds SA → ClusterRole

### Verification
```bash
kubectl auth can-i get pods --as=system:serviceaccount:insighthub:mcp-readonly    # yes
kubectl auth can-i delete pods --as=system:serviceaccount:insighthub:mcp-readonly  # no
```

---

## Case Study 4: Filesystem Allow-List

**Problem**: Filesystem MCP must not access root or home directory.

### Fix
- `.mcp.json` filesystem args: only `C:/Study/DevOps/insighthubTest1`.
- Verified: no `/`, `$HOME`, or `/home/<user>` patterns in args.

---

**Last Updated**: 2026-06-06
**Status**: ✅ Complete — 4 case studies documented
