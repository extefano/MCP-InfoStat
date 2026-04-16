from __future__ import annotations

from pathlib import Path

from mcp_infostat.errors import InfoStatError


class PathSecurityPolicy:
    def __init__(self, base_dir: Path, allowed_extensions: tuple[str, ...], max_file_size_mb: int):
        self.base_dir = base_dir.resolve()
        self.allowed_extensions = tuple(ext.lower() for ext in allowed_extensions)
        self.max_file_size_bytes = max_file_size_mb * 1024 * 1024

        self.base_dir.mkdir(parents=True, exist_ok=True)

    def validate_input_path(self, raw_path: str) -> Path:
        incoming = Path(raw_path)
        candidate = incoming if incoming.is_absolute() else self.base_dir / incoming
        resolved = candidate.resolve()

        try:
            resolved.relative_to(self.base_dir)
        except ValueError as exc:
            raise InfoStatError(
                code="SECURITY_PATH_OUTSIDE_BASE_DIR",
                message="El archivo esta fuera del directorio permitido.",
                details={"base_dir": str(self.base_dir), "requested": str(resolved)},
            ) from exc

        ext = resolved.suffix.lower()
        if ext not in self.allowed_extensions:
            raise InfoStatError(
                code="SECURITY_EXTENSION_NOT_ALLOWED",
                message="Extension de archivo no permitida.",
                details={"extension": ext, "allowed": list(self.allowed_extensions)},
            )

        if not resolved.exists():
            raise InfoStatError(
                code="FILE_NOT_FOUND",
                message="No se encontro el archivo solicitado.",
                details={"requested": str(resolved)},
            )

        file_size = resolved.stat().st_size
        if file_size > self.max_file_size_bytes:
            raise InfoStatError(
                code="SECURITY_FILE_TOO_LARGE",
                message="El archivo excede el tamano maximo permitido.",
                details={
                    "requested": str(resolved),
                    "size_bytes": file_size,
                    "max_bytes": self.max_file_size_bytes,
                },
            )

        return resolved
