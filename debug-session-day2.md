# Day 2 Debug Session Log — InsightHub

## Case Study: Investigating Unhealthy 'web' Container

**Problem Statement**: 
User reports the web interface is slow or unreachable. `docker ps` shows `insighthub-web-1` status as `unhealthy`.

**Tools Used via MCP**:
- **Docker MCP**: To inspect container state and logs.
- **Filesystem MCP**: To check Dockerfile configuration.

**Step 1: Perceive — Check Container Status**
- Action: `docker ps` (Simulated via Docker MCP `list_containers`)
- Observation: `insighthub-web-1` is `unhealthy`.

**Step 2: Reason — Why is it unhealthy?**
- Action: `docker inspect insighthub-web-1` (Simulated via Docker MCP `inspect_container`)
- Observation: 
  ```json
  "Log": [
    {
      "ExitCode": 1,
      "Output": "Connecting to localhost:3000 ([::1]:3000)\nwget: can't connect to remote host: Connection refused\n"
    }
  ]
  ```
- Inference: The healthcheck command `wget localhost:3000` is attempting to connect via IPv6 loopback (`::1`), but the Next.js app is likely listening on IPv4 (`0.0.0.0`) only inside the container.

**Step 3: Act — Verify Dockerfile Healthcheck**
- Action: Read `web/Dockerfile` (via Filesystem MCP)
- Observation:
  ```dockerfile
  HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1
  ```

**Step 4: Act — Fix the Healthcheck**
- Strategy: Force IPv4 by using `127.0.0.1` instead of `localhost`.
- Action: Modified `web/Dockerfile`.

**Step 5: Observe — Verify Fix**
- Action: Rebuild and restart.
- Result: `insighthub-web-1` status becomes `healthy`.

---

## Least-Privilege Verification (AWS)

**Task**: Attempt to create an S3 bucket using the `mcp-readonly` profile.
**Tool**: AWS MCP `create_bucket`
**Result**: 
```
An error occurred (AccessDenied) when calling the CreateBucket operation: 
User: arn:aws:iam::123456789012:user/mcp-readonly is not authorized to perform: 
s3:CreateBucket on resource: "*"
```
**Conclusion**: Least-privilege is successfully enforced via IAM policies.
