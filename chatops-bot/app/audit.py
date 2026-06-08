"""InsightHub ChatOps Bot — NDJSON audit log."""

import json
import logging
import os
from datetime import datetime, timezone

logger = logging.getLogger("chatops-bot.audit")

LOG_PATH = os.getenv("CHATOPS_AUDIT_LOG", "chatops-audit.log")


def log_tool_call(
    user: str,
    tool: str,
    args: dict,
    result_summary: str,
    approved: bool = True,
) -> None:
    record = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "user": user,
        "tool": tool,
        "args": args,
        "result": result_summary,
        "approved": approved,
    }
    line = json.dumps(record, ensure_ascii=False, default=str)
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(line + "\n")
    logger.info("AUDIT %s", line)
