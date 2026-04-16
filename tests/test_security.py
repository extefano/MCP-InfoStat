from pathlib import Path

import pytest

from mcp_infostat.errors import InfoStatError
from mcp_infostat.security import PathSecurityPolicy


def _policy(tmp_path: Path) -> PathSecurityPolicy:
    return PathSecurityPolicy(
        base_dir=tmp_path,
        allowed_extensions=(".csv", ".txt"),
        max_file_size_mb=1,
    )


def test_validate_input_path_accepts_file_inside_base(tmp_path: Path) -> None:
    policy = _policy(tmp_path)
    dataset = tmp_path / "ok.csv"
    dataset.write_text("a,b\n1,2\n", encoding="utf-8")

    resolved = policy.validate_input_path(str(dataset))
    assert resolved == dataset.resolve()


def test_validate_input_path_rejects_outside_base(tmp_path: Path) -> None:
    policy = _policy(tmp_path)
    outside = tmp_path.parent / "outside.csv"
    outside.write_text("x,y\n", encoding="utf-8")

    with pytest.raises(InfoStatError) as exc_info:
        policy.validate_input_path(str(outside))

    assert exc_info.value.code == "SECURITY_PATH_OUTSIDE_BASE_DIR"


def test_validate_input_path_rejects_extension(tmp_path: Path) -> None:
    policy = _policy(tmp_path)
    dataset = tmp_path / "bad.xlsx"
    dataset.write_text("dummy", encoding="utf-8")

    with pytest.raises(InfoStatError) as exc_info:
        policy.validate_input_path(str(dataset))

    assert exc_info.value.code == "SECURITY_EXTENSION_NOT_ALLOWED"
