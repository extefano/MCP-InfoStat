from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class InfoStatError(Exception):
    code: str
    message: str
    details: dict[str, Any] = field(default_factory=dict)

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.code}: {self.message}"


def build_error_payload(exc: InfoStatError) -> dict[str, Any]:
    return {
        "code": exc.code,
        "message": exc.message,
        "details": exc.details,
    }
