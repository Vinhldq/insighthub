"""InsightHub ChatOps Bot — multi-provider LLM client with tool-calling."""

from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Any

import anthropic
import httpx

logger = logging.getLogger("chatops-bot.llm")

PROVIDER = os.getenv("CHATOPS_LLM_PROVIDER", "gemini").lower()
API_KEY = os.getenv(
    f"{PROVIDER.upper()}_API_KEY",
    os.getenv("GEMINI_API_KEY", os.getenv("ANTHROPIC_API_KEY", "")),
)
BASE_URL = os.getenv(f"{PROVIDER.upper()}_BASE_URL", "")

MODELS = {
    "deepseek": os.getenv("DEEPSEEK_CHAT_MODEL", "deepseek-v4-flash"),
    "gemini": os.getenv("GEMINI_CHAT_MODEL", "gemini-3-flash-preview"),
    "anthropic": os.getenv("ANTHROPIC_CHAT_MODEL", "claude-sonnet-4-6"),
}
MODEL = MODELS.get(PROVIDER, "gemini-3-flash-preview")

SYSTEM_PROMPT_PATH = Path(__file__).resolve().parent.parent / "prompts" / "system.md"


def load_system_prompt() -> str:
    try:
        return SYSTEM_PROMPT_PATH.read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        return (
            "You are an AI DevOps assistant for InsightHub. "
            "Use available tools to answer questions about the infrastructure."
        )


def _anthropic_call(messages: list[dict]) -> anthropic.types.Message:
    client = anthropic.Anthropic(api_key=API_KEY)
    return client.messages.create(
        model=MODEL,
        max_tokens=2048,
        system=load_system_prompt(),
        tools=_format_tools(),
        messages=messages,
    )


def _openai_compat_call(messages: list[dict]) -> dict:
    url = BASE_URL or {
        "deepseek": "https://api.deepseek.com/v1/chat/completions",
        "gemini": "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
    }.get(PROVIDER, "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")

    body: dict[str, Any] = {
        "model": MODEL,
        "messages": [{"role": "system", "content": load_system_prompt()}] + messages,
        "max_tokens": 2048,
        "tools": _format_tools(),
        "tool_choice": "auto",
    }
    headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
    with httpx.Client(timeout=60) as client:
        resp = client.post(url, headers=headers, json=body)
        resp.raise_for_status()
        return resp.json()


def _format_tools() -> list[dict]:
    from app.tools import list_tools
    return [
        {
            "type": "function",
            "function": {
                "name": t["name"],
                "description": f"Call {t['name']} (tier: {t['tier']})",
                "parameters": {
                    "type": "object",
                    "properties": {},
                    "required": [],
                },
            },
        }
        for t in list_tools()
    ]


def chat(messages: list[dict]) -> Any:
    if PROVIDER == "anthropic":
        return _anthropic_call(messages)
    return _openai_compat_call(messages)


def extract_text(resp: Any) -> str:
    if PROVIDER == "anthropic":
        for block in resp.content:
            if block.type == "text":
                return block.text
        return ""
    choices = resp.get("choices", [])
    if not choices:
        return ""
    msg = choices[0].get("message", {})
    return msg.get("content", "") or ""


def extract_tool_calls(resp: Any) -> list[dict]:
    if PROVIDER == "anthropic":
        calls = []
        for block in resp.content:
            if block.type == "tool_use":
                calls.append({
                    "id": block.id,
                    "type": "function",
                    "function": {
                        "name": block.name,
                        "arguments": json.dumps(block.input),
                    },
                })
        return calls
    msg = resp.get("choices", [{}])[0].get("message", {})
    return msg.get("tool_calls", [])
