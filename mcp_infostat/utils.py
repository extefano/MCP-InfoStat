from __future__ import annotations

import time
from typing import Any


def build_response(
    *,
    success: bool,
    operation: str,
    started_at: float,
    result: dict[str, Any],
    warnings: list[str] | None = None,
    error: dict[str, Any] | None = None,
) -> dict[str, Any]:
    duration_ms = int((time.perf_counter() - started_at) * 1000)
    return {
        "success": success,
        "operation": operation,
        "duration_ms": duration_ms,
        "result": result,
        "warnings": warnings or [],
        "error": error,
    }
