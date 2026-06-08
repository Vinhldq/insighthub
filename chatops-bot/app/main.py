"""InsightHub ChatOps Bot — FastAPI app with Slack integration."""

from __future__ import annotations

import hashlib
import hmac
import logging
import os
from contextvars import ContextVar
from datetime import datetime, timezone

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

from app.handler import handle_question

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger("chatops-bot.main")

app = FastAPI(title="InsightHub ChatOps Bot")

SLACK_SIGNING_SECRET = os.getenv("SLACK_SIGNING_SECRET", "")
SLACK_BOT_TOKEN = os.getenv("SLACK_BOT_TOKEN", "")
CHANNEL: ContextVar[str] = ContextVar("channel", default="")
USER_ID: ContextVar[str] = ContextVar("user_id", default="unknown")
slack_client = WebClient(token=SLACK_BOT_TOKEN) if SLACK_BOT_TOKEN else None


@app.get("/healthz")
async def health():
    return {"status": "ok"}


@app.post("/slack/events")
async def slack_events(request: Request):
    timestamp = request.headers.get("X-Slack-Request-Timestamp", "")
    signature = request.headers.get("X-Slack-Signature", "")

    if not verify_signature(await request.body(), timestamp, signature):
        return JSONResponse({"error": "invalid signature"}, status_code=401)

    body = await request.json()

    if body.get("type") == "url_verification":
        return {"challenge": body.get("challenge")}

    if body.get("type") != "event_callback":
        return {"ok": True}

    event = body.get("event", {})
    event_type = event.get("type")
    user = event.get("user", "unknown")
    text = event.get("text", "").strip()
    channel = event.get("channel", "")
    event_ts = event.get("ts", "")

    if event_type == "app_mention":
        CHANNEL.set(channel)
        USER_ID.set(user)
        question = text.split(maxsplit=1)[-1].strip() if " " in text else ""
        if not question:
            post_message(channel, "Bạn muốn hỏi gì? Tag tôi và đặt câu hỏi.", event_ts)
            return {"ok": True}
        post_message(channel, f"Đang xử lý: *{question}*...", event_ts)
        try:
            answer = handle_question(question, user)
            post_message(channel, answer, event_ts)
        except Exception as exc:
            logger.exception("handle_question failed")
            post_message(channel, f"Lỗi: {exc}", event_ts)

    return {"ok": True}


def verify_signature(body: bytes, timestamp: str, signature: str) -> bool:
    if not SLACK_SIGNING_SECRET:
        logger.warning("SLACK_SIGNING_SECRET not set — skipping verification")
        return True
    basestring = f"v0:{timestamp}:{body.decode('utf-8', errors='replace')}"
    expected = "v0=" + hmac.new(
        SLACK_SIGNING_SECRET.encode(),
        basestring.encode(),
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


def post_message(channel: str, text: str, thread_ts: str = "") -> None:
    if not slack_client:
        logger.info("Would post to %s: %s", channel, text)
        return
    try:
        slack_client.chat_postMessage(
            channel=channel,
            text=text,
            thread_ts=thread_ts,
        )
    except SlackApiError as exc:
        logger.error("Slack API error: %s", exc)
