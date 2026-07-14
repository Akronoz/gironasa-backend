"""Thread-safe fan-out of live I/O telemetry events to dashboard SSE clients."""

from __future__ import annotations

import queue
import threading
from typing import Any

IO_LIVE_METRICS = frozenset({"output", "output_mode", "input"})


class LiveEventHub:
    def __init__(self) -> None:
        self._subscribers: list[queue.Queue[dict[str, Any]]] = []
        self._lock = threading.Lock()

    def subscribe(self, *, maxsize: int = 128) -> queue.Queue[dict[str, Any]]:
        q: queue.Queue[dict[str, Any]] = queue.Queue(maxsize=maxsize)
        with self._lock:
            self._subscribers.append(q)
        return q

    def unsubscribe(self, q: queue.Queue[dict[str, Any]]) -> None:
        with self._lock:
            if q in self._subscribers:
                self._subscribers.remove(q)

    def publish(self, event: dict[str, Any]) -> None:
        with self._lock:
            subscribers = list(self._subscribers)
        for subscriber in subscribers:
            try:
                subscriber.put_nowait(event)
            except queue.Full:
                pass


live_hub = LiveEventHub()


def _resolve_io_metric(event: dict[str, Any]) -> str | None:
    """Bridge uses metric=output_1; accept base names and category fallback."""
    metric = str(event.get("metric", "")).strip().lower()
    category = str(event.get("category", "")).strip().lower()

    if metric in IO_LIVE_METRICS:
        return metric
    if category in IO_LIVE_METRICS:
        return category
    for base in IO_LIVE_METRICS:
        if metric.startswith(f"{base}_"):
            return base
    return None


def io_event_from_telemetry(event: dict[str, Any]) -> dict[str, Any] | None:
    metric = _resolve_io_metric(event)
    if metric is None:
        return None

    device_id = str(event.get("device_id", "")).strip()
    channel = event.get("channel")
    if not device_id or channel is None:
        return None

    try:
        channel_num = int(channel)
    except (TypeError, ValueError):
        return None
    if channel_num < 1 or channel_num > 4:
        return None

    payload = event.get("payload")
    value = event.get("value")
    if isinstance(value, bool):
        value = int(value)

    return {
        "type": "io",
        "device_id": device_id,
        "metric": metric,
        "channel": str(channel_num),
        "value": value,
        "payload": str(payload) if payload is not None else None,
        "received_at": event.get("received_at"),
    }