from __future__ import annotations

from pathlib import Path
from typing import Literal

from pydantic import BaseModel, Field

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib  # type: ignore[no-redef]


class InfoStatConfig(BaseModel):
    exe_path: str
    version: str = "InfoStat 2008"


class PathsConfig(BaseModel):
    data_base_dir: Path = Field(default_factory=lambda: Path("./data"))
    results_base_dir: Path = Field(default_factory=lambda: Path("./results"))


class TimeoutsConfig(BaseModel):
    launch_seconds: float = 30
    dialog_appear_seconds: float = 10
    analysis_complete_seconds: float = 120


class MCPConfig(BaseModel):
    transport: Literal["stdio", "http"] = "stdio"


class SecurityConfig(BaseModel):
    allowed_extensions: list[str] = Field(default_factory=lambda: [".csv", ".txt", ".xls", ".xlsx", ".dbf"])
    max_file_size_mb: int = 100


class AppConfig(BaseModel):
    infostat: InfoStatConfig
    paths: PathsConfig
    timeouts: TimeoutsConfig
    mcp: MCPConfig
    security: SecurityConfig


def load_config(config_path: Path) -> AppConfig:
    if not config_path.exists():
        raise FileNotFoundError(f"No se encontro config.toml en {config_path}")

    data = tomllib.loads(config_path.read_text(encoding="utf-8"))
    config = AppConfig.model_validate(data)

    root = config_path.parent
    config.paths.data_base_dir = (root / config.paths.data_base_dir).resolve()
    config.paths.results_base_dir = (root / config.paths.results_base_dir).resolve()

    return config
