from mcp_infostat.utils import build_response


def test_build_response_success_shape() -> None:
    response = build_response(
        success=True,
        operation="infostat_status",
        started_at=0.0,
        result={"running": True},
    )

    assert response["success"] is True
    assert response["operation"] == "infostat_status"
    assert response["result"] == {"running": True}
    assert response["warnings"] == []
    assert response["error"] is None
    assert isinstance(response["duration_ms"], int)
