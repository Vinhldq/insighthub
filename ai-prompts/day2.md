# Day 2 AI Prompts — MCP Protocol Implementation

**Tool**: Claude Opus 4.6
**Date**: 2026-06-06

---

## Prompt 1 — Configure 5 MCP Servers

**Prompt**:
Cấu hình `.mcp.json` cho InsightHub với 5 MCP servers theo spec:
1. filesystem: `@modelcontextprotocol/server-filesystem@2026.1.14`, allow-list chỉ project directory
2. docker: `docker mcp gateway run` (Docker Desktop ≥ 4.40)
3. kubernetes: `kubernetes-mcp-server@0.0.62` với `--read-only` flag
4. prometheus: `@wkronmiller/prometheus-mcp-server@2.0.0`, endpoint localhost:9090
5. aws: `uvx awslabs.aws-api-mcp-server@1.3.38`, dùng `AWS_PROFILE=mcp-readonly`
Yêu cầu: pin version chính xác, KHÔNG dùng @latest, credentials qua env vars.

**Why it worked**: Yêu cầu rõ từng server với version + command + security flags. Agent so sánh với CLAUDE.md spec table và cấu hình chính xác.

---

## Prompt 2 — Debug Unhealthy Container via MCP

**Prompt**:
Dùng MCP servers (Docker + Filesystem) để debug container `insighthub-web-1` unhealthy:
1. Docker MCP: `list_containers` → xác định container unhealthy
2. Docker MCP: `inspect_container` → đọc healthcheck log
3. Filesystem MCP: read `web/Dockerfile` → xác định healthcheck command
4. Phân tích: `wget localhost:3000` resolve sang IPv6 `::1` nhưng Next.js listen trên IPv4
5. Fix: đổi `localhost` → `127.0.0.1` trong HEALTHCHECK
6. Ghi lại quy trình Perceive → Reason → Act → Observe

**Why it worked**: Case study thực tế, agent dùng MCP tools trực tiếp để investigate và fix bug Docker healthcheck.

---

## Prompt 3 — Create K8s RBAC for MCP Read-Only

**Prompt**:
Tạo K8s RBAC manifests cho MCP kubernetes server theo least-privilege:
- Namespace: `insighthub`
- ServiceAccount: `mcp-readonly` trong namespace `insighthub`
- ClusterRole: `mcp-readonly` với quyền GET/LIST/WATCH cho: pods, services, nodes, deployments, replicasets, ingresses, networkpolicies, configmaps
- ClusterRoleBinding: bind SA → ClusterRole
- KHÔNG cho quyền CREATE/UPDATE/DELETE
- Lưu tại `infra/k8s/mcp-readonly/`

**Why it worked**: Yêu cầu cụ thể từng resource và verb, agent tạo 4 YAML files match CLAUDE.md security section.

---

## Prompt 4 — Verify Security Constraints

**Prompt**:
Chạy các kiểm tra bảo mật cho Day 2:
1. `jq '.mcpServers | length' .mcp.json` → phải = 5
2. Kiểm tra không có `@latest` hoặc `@main` trong version
3. `kubectl auth can-i get pods --as=system:serviceaccount:insighthub:mcp-readonly` → yes
4. `kubectl auth can-i delete pods --as=system:serviceaccount:insighthub:mcp-readonly` → no
5. Filesystem allow-list: không chứa `/`, `$HOME`, `/home/<user>`

**Why it worked**: Verification commands cụ thể, agent chạy từng check và xác nhận pass.

---

## Prompt 5 — Write Debug Session Log

**Prompt**:
Tạo `debug-session-day2.md` ghi lại 4 case studies:
1. Unhealthy container → Docker MCP debug → fix healthcheck IPv4
2. MCP config version mismatches → fix .mcp.json
3. K8s RBAC setup → create 4 manifests
4. Filesystem allow-list security
Mỗi case study theo format: Perceive → Reason → Act → Observe.

**Why it worked**: Structure rõ ràng, agent dùng thông tin từ các prompts trước để ghi log consistent.

---

**Status**: ✅ Complete — 5 MCP servers configured, 4 K8s RBAC manifests, debug session with 4 case studies
