"""InsightHub ChatOps Bot — K8s, Prometheus, API health tools."""

from __future__ import annotations

import logging
import subprocess
import time
from urllib.error import URLError
from urllib.request import Request, urlopen

from .permissions import PermissionTier, classify, DESTRUCTIVE_KEYWORDS, WRITE_KEYWORDS

logger = logging.getLogger("chatops-bot.tools")


def _k8s(args: str) -> str:
    cmd = f"kubectl {args}"
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=15,
        )
        if result.returncode != 0:
            return f"Error: {result.stderr.strip()}"
        return result.stdout.strip() or "(empty)"
    except subprocess.TimeoutExpired:
        return "Error: kubectl timed out"
    except Exception as exc:
        return f"Error: {exc}"


def _prometheus(query: str) -> str:
    base = "http://localhost:9090"
    try:
        url = f"{base}/api/v1/query?query={query}"
        req = Request(url, headers={"User-Agent": "chatops-bot"})
        with urlopen(req, timeout=10) as resp:
            import json
            data = json.loads(resp.read().decode())
        results = data.get("data", {}).get("result", [])
        if not results:
            return "No data"
        parts = []
        for r in results:
            val = r.get("value", [None, "?"])[1]
            metric = ", ".join(f"{k}={v}" for k, v in r.get("metric", {}).items())
            parts.append(f"{metric} = {val}")
        return "; ".join(parts)
    except (URLError, OSError) as exc:
        return f"Error: {exc}"


def _api_health(url: str) -> str:
    try:
        req = Request(f"{url}/healthz", headers={"User-Agent": "chatops-bot"})
        t0 = time.monotonic()
        with urlopen(req, timeout=5) as resp:
            _ = resp.read()
        ms = round((time.monotonic() - t0) * 1000)
        return f"OK ({ms}ms)"
    except (URLError, OSError) as exc:
        return f"Error: {exc}"


ALL_TOOLS: dict[str, dict] = {}


def _register(name: str, tier: PermissionTier, func):
    ALL_TOOLS[name] = {"tier": tier.value, "func": func}


_register("get_pods", PermissionTier.READ,
          lambda ns: _k8s(f"get pods -n {ns} -o wide"))
_register("get_pod_logs", PermissionTier.READ,
          lambda ns, pod, lines="100": _k8s(f"logs -n {ns} {pod} --tail={lines}"))
_register("get_events", PermissionTier.READ,
          lambda ns: _k8s(f"get events -n {ns} --sort-by='.lastTimestamp'"))
_register("describe_pod", PermissionTier.READ,
          lambda ns, pod: _k8s(f"describe pod -n {ns} {pod}"))
_register("get_deployments", PermissionTier.READ,
          lambda ns: _k8s(f"get deployments -n {ns}"))
_register("get_nodes", PermissionTier.READ,
          lambda: _k8s("get nodes -o wide"))

_register("scale_deployment", PermissionTier.WRITE,
          lambda ns, deploy, replicas: _k8s(
              f"scale deployment -n {ns} {deploy} --replicas={replicas}"))
_register("restart_deployment", PermissionTier.WRITE,
          lambda ns, deploy: _k8s(
              f"rollout restart deployment -n {ns} {deploy}"))
_register("rollout_status", PermissionTier.READ,
          lambda ns, deploy: _k8s(
              f"rollout status deployment -n {ns} {deploy} --timeout=10s"))
_register("apply", PermissionTier.WRITE,
          lambda ns, manifest: _k8s(f"apply -n {ns} -f {manifest}"))

_register("prometheus_query", PermissionTier.READ,
          lambda query: _prometheus(query))
_register("api_health", PermissionTier.READ,
          lambda url="http://localhost:8000": _api_health(url))


def get_tool(name: str):
    info = ALL_TOOLS.get(name)
    return info["func"] if info else None


def get_tier(name: str) -> PermissionTier | None:
    info = ALL_TOOLS.get(name)
    if not info:
        return None
    return PermissionTier(info["tier"])


def classify_tool(name: str, args: dict) -> PermissionTier:
    info = ALL_TOOLS.get(name)
    if info:
        return PermissionTier(info["tier"])
    return classify(name, args)


def list_tools() -> list[dict]:
    return [
        {"name": name, "tier": info["tier"]}
        for name, info in ALL_TOOLS.items()
    ]
