"""InsightHub ChatOps Bot — tool-calling loop with permission enforcement."""

from __future__ import annotations

import json
import logging
import os
from typing import Any

from app.audit import log_tool_call
from app.llm import chat, extract_text, extract_tool_calls
from app.permissions import PermissionTier, is_allowed
from app.tools import classify_tool, get_tool, get_tier

logger = logging.getLogger("chatops-bot.handler")
NAMESPACE = os.getenv("K8S_NAMESPACE", "default")
API_URL = os.getenv("INSIGHTHUB_API_URL", "http://localhost:8000")


def handle_question(question: str, user: str) -> str:
    messages = [{"role": "user", "content": question}]
    max_rounds = 5

    for _ in range(max_rounds):
        resp = chat(messages)
        calls = extract_tool_calls(resp)

        if not calls:
            return extract_text(resp) or "Không có câu trả lời."

        results = []
        for call in calls:
            name = call.get("function", {}).get("name", "")
            args_raw = call.get("function", {}).get("arguments", "{}")
            try:
                args: dict = json.loads(args_raw)
            except (json.JSONDecodeError, TypeError):
                args = {}

            if "ns" not in args:
                args["ns"] = NAMESPACE
            if "url" not in args and name == "api_health":
                args["url"] = API_URL

            tier = get_tier(name) or classify_tool(name, args)
            if not is_allowed(tier):
                result = f"Denied: {name} ({tier.value}) cần approval — không được tự động thực hiện."
            else:
                func = get_tool(name)
                if func is None:
                    result = f"Unknown tool: {name}"
                else:
                    try:
                        result = func(**args)
                    except TypeError:
                        result = f"Bad args for {name}: {args_raw}"
                    except Exception as exc:
                        result = f"Error: {exc}"

            log_tool_call(user=user, tool=name, args=args, result_summary=result[:200])

            results.append({
                "tool_call_id": call.get("id", ""),
                "role": "tool",
                "content": str(result)[:4000],
            })

        messages.append({
            "role": "assistant",
            "content": None,
            "tool_calls": calls,
        })
        messages.extend(results)

    return extract_text(chat(messages)) or "Không thể hoàn thành sau nhiều lần thử."
