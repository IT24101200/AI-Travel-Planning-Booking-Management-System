"""Offline by default: tests must supply catalogue/model responses explicitly."""

import httpx
import pytest
import requests


@pytest.fixture(autouse=True)
def isolate_external_services(monkeypatch, tmp_path, request):
    import logger

    monkeypatch.setenv("AGENT_EVIDENCE_DIR", str(tmp_path / "evidence"))
    monkeypatch.setenv("AGENT_EVIDENCE_CONTEXT", "test")

    def no_network(*args, **kwargs):
        raise AssertionError("Unit tests must mock external HTTP calls")

    # FastAPI's in-process TestClient and explicit MockTransport still work.
    monkeypatch.setattr(httpx.HTTPTransport, "handle_request", no_network)
    monkeypatch.setattr(requests.sessions.Session, "request", no_network)
    # Logging tests exercise their own mocked transport; other tests retain
    # real local evidence but never wait for a backend audit connection.
    if request.node.path.name != "test_agent_logging.py":
        monkeypatch.setattr(logger, "_post_audit_payload", lambda payload: None)
