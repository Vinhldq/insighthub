"""InsightHub ChatOps Bot — 3-tier permission system."""

from enum import Enum


class PermissionTier(Enum):
    READ = "read"
    WRITE = "write"
    DESTRUCTIVE = "destructive"


DESTRUCTIVE_KEYWORDS = {
    "delete", "destroy", "drop", "purge", "drain", "evict",
    "terminate", "shutdown", "kill",
}

WRITE_KEYWORDS = {
    "scale", "restart", "rollout", "apply", "update", "patch",
    "create", "exec", "port-forward", "rollout restart",
}


def classify(tool: str, args: dict) -> PermissionTier:
    combined = f"{tool} {' '.join(str(v) for v in args.values())}".lower()
    for kw in DESTRUCTIVE_KEYWORDS:
        if kw in combined:
            return PermissionTier.DESTRUCTIVE
    for kw in WRITE_KEYWORDS:
        if kw in combined:
            return PermissionTier.WRITE
    return PermissionTier.READ


def is_allowed(tier: PermissionTier) -> bool:
    return tier != PermissionTier.DESTRUCTIVE
