"""Thin Bedrock Converse client: global rate limit, retry with backoff, async wrappers.

boto3 is synchronous, so calls run in worker threads. Streaming events are pushed
from the worker thread into an asyncio queue.
"""

from __future__ import annotations

import asyncio
import random
import threading
from collections.abc import AsyncIterator
from typing import Any, Protocol

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from app.agent.ratelimit import TokenBucket
from app.config import Settings
from app.core.logging import log

RETRYABLE = {"ThrottlingException", "ServiceUnavailableException", "ModelNotReadyException"}
MAX_ATTEMPTS = 4


class LlmUnavailable(RuntimeError):
    """Bedrock could not be reached or refused the call; callers fall back to templates."""


class ConverseClient(Protocol):
    async def converse(self, **kwargs: Any) -> dict[str, Any]: ...

    def converse_stream(self, **kwargs: Any) -> AsyncIterator[dict[str, Any]]: ...


class BedrockClient:
    def __init__(self, settings: Settings, bucket: TokenBucket) -> None:
        session = boto3.Session(
            profile_name=settings.aws_profile or None, region_name=settings.aws_region
        )
        self._client = session.client(
            "bedrock-runtime",
            config=Config(retries={"max_attempts": 1}, read_timeout=60, connect_timeout=5),
        )
        self._bucket = bucket

    async def _with_retry(self, fn: Any, **kwargs: Any) -> Any:
        for attempt in range(MAX_ATTEMPTS):
            await self._bucket.acquire()
            try:
                return await asyncio.to_thread(fn, **kwargs)
            except ClientError as e:
                code = e.response.get("Error", {}).get("Code", "")
                if code in RETRYABLE and attempt < MAX_ATTEMPTS - 1:
                    delay = (2**attempt) + random.random()
                    log.warning("bedrock_retry", code=code, attempt=attempt, delay=round(delay, 2))
                    await asyncio.sleep(delay)
                    continue
                log.error("bedrock_error", code=code, message=str(e)[:200])
                raise LlmUnavailable(code or "ClientError") from e
            except Exception as e:  # network, credentials, expired token
                log.error("bedrock_unreachable", error=type(e).__name__, message=str(e)[:200])
                raise LlmUnavailable(type(e).__name__) from e
        raise LlmUnavailable("retries exhausted")

    async def converse(self, **kwargs: Any) -> dict[str, Any]:
        result: dict[str, Any] = await self._with_retry(self._client.converse, **kwargs)
        return result

    async def converse_stream(self, **kwargs: Any) -> AsyncIterator[dict[str, Any]]:
        response = await self._with_retry(self._client.converse_stream, **kwargs)
        loop = asyncio.get_running_loop()
        queue: asyncio.Queue[dict[str, Any] | BaseException | None] = asyncio.Queue()

        def pump() -> None:
            try:
                for event in response["stream"]:
                    loop.call_soon_threadsafe(queue.put_nowait, event)
            except BaseException as e:  # surfaced to the consumer below
                loop.call_soon_threadsafe(queue.put_nowait, e)
            finally:
                loop.call_soon_threadsafe(queue.put_nowait, None)

        threading.Thread(target=pump, name="bedrock-stream", daemon=True).start()
        while True:
            item = await queue.get()
            if item is None:
                return
            if isinstance(item, BaseException):
                raise LlmUnavailable(type(item).__name__) from item
            yield item
