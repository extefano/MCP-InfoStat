from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any

from mcp_infostat.errors import InfoStatError

try:
    from pywinauto import Application
    from pywinauto.timings import wait_until_passes
except Exception:  # pragma: no cover - se valida en runtime
    Application = None  # type: ignore[assignment]
    wait_until_passes = None  # type: ignore[assignment]


class InfoStatLauncher:
    def __init__(self, default_exe_path: str):
        self.default_exe_path = default_exe_path
        self._app: Application | None = None
        self._process: subprocess.Popen[Any] | None = None

    def launch(self, exe_path: str | None = None, timeout: float = 30) -> dict[str, Any]:
        if Application is None or wait_until_passes is None:
            raise InfoStatError(
                code="DEPENDENCY_MISSING",
                message="pywinauto no esta disponible en el entorno actual.",
            )

        effective_path = Path(exe_path or self.default_exe_path)
        if not effective_path.exists():
            raise InfoStatError(
                code="INFOSTAT_EXE_NOT_FOUND",
                message="No se encontro el ejecutable de InfoStat.",
                details={"path": str(effective_path)},
            )

        self._process = subprocess.Popen([str(effective_path)])
        self._app = Application(backend="win32")

        def _connect() -> None:
            assert self._app is not None
            self._app.connect(process=self._process.pid)

        try:
            wait_until_passes(timeout=timeout, retry_interval=0.5, func=_connect)
        except Exception as exc:
            raise InfoStatError(
                code="INFOSTAT_LAUNCH_TIMEOUT",
                message="Timeout esperando que InfoStat quede disponible.",
                details={"timeout_seconds": timeout},
            ) from exc

        return {"pid": self._process.pid}

    def is_ready(self) -> bool:
        if self._app is None or self._process is None:
            return False
        if self._process.poll() is not None:
            return False
        return True

    def close(self, save_before_close: bool = False) -> None:
        if self._process is None:
            return

        # En Sprint 1 no se automatiza dialogo de guardado; se cierra el proceso.
        if self._process.poll() is None:
            self._process.terminate()
            self._process.wait(timeout=10)

        self._process = None
        self._app = None
