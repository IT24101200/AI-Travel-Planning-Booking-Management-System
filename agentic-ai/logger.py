"""
logger.py - Shared Agent Audit Logger
Records observable agent steps in local JSONL and the backend audit database.
Local full-output evidence remains available when the backend audit call fails.
"""

import os
import json
import logging
import re
from datetime import datetime, timezone
from contextlib import contextmanager
from contextvars import ContextVar
from uuid import uuid4
import httpx
from dotenv import load_dotenv
from evidence import append_record, bounded_json, sanitize

# Load environment variables
load_dotenv()

# Configure local console logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s"
)
console = logging.getLogger("AgentLogger")


class _RedactApiKeys(logging.Filter):
    def filter(self, record):
        message = record.getMessage()
        redacted = re.sub(r"([?&](?:key|api_key|access_token)=)[^&\s\"']+", r"\1[REDACTED]", message, flags=re.IGNORECASE)
        if redacted != message:
            record.msg, record.args = redacted, ()
        return True


for _logger in (console, logging.getLogger("httpx")):
    _logger.addFilter(_RedactApiKeys())

def _normalise_backend_url(value: str) -> str:
    normalised = value.rstrip("/")
    return normalised[:-4] if normalised.lower().endswith("/api") else normalised


BACKEND_URL = _normalise_backend_url(
    os.getenv("BACKEND_URL") or os.getenv("BACKEND_API_URL") or "http://localhost:5138"
)
AGENT_SERVICE_API_KEY = os.getenv("AGENT_SERVICE_API_KEY", "").strip()
_audit_client = ContextVar("audit_client", default=None)
_audit_run_id = ContextVar("audit_run_id", default=None)


@contextmanager
def audit_log_session():
    """Reuse connections within a pipeline; concurrent trips stay isolated."""
    with httpx.Client(timeout=httpx.Timeout(5.0, connect=2.0)) as client:
        token = _audit_client.set(client)
        run_token = _audit_run_id.set(uuid4().hex)
        try:
            yield
        finally:
            _audit_client.reset(token)
            _audit_run_id.reset(run_token)


def agent_service_headers():
    return {"X-Agent-Service-Key": AGENT_SERVICE_API_KEY} if AGENT_SERVICE_API_KEY else {}


def format_payload(data):
    """Safely converts input/output data to a string for DB storage."""
    if data is None:
        return None
    if isinstance(data, (dict, list)):
        try:
            return json.dumps(data, indent=2, default=str)
        except Exception:
            return str(data)
    return str(data)


def log_agent_step(
    trip_request_id: int,
    agent_name: str,
    step_name: str,
    step_type: str = "Reasoning",
    tool_name: str = None,
    input_data=None,
    output_data=None,
    status: str = "Success",
    duration_ms: int = None,
    reason: str = None,
    execution_mode: str = "deterministic",
    model: str = None,
):
    """
    Sends an agent audit log entry to the ASP.NET Core backend API.
    Persists to the PostgreSQL AgentLogs table.
    """
    now_iso = datetime.now(timezone.utc).isoformat()
    # Keep evidence metadata inside Output because the backend's StepType,
    # ToolName and DurationMs properties are currently NotMapped by EF Core.
    evidence_output = dict(output_data) if isinstance(output_data, dict) else {"result": output_data}
    evidence_output["_evidence"] = {
        "schema_version": 1,
        "context": os.getenv("AGENT_EVIDENCE_CONTEXT", "runtime"),
        "run_id": _audit_run_id.get() or uuid4().hex,
        "reason": str(reason or (output_data.get("error") if isinstance(output_data, dict) else None) or step_name)[:700],
        "execution_mode": execution_mode,
        "model": model,
        "step_type": step_type,
        "tool_name": tool_name,
        "duration_ms": duration_ms,
    }
    safe_input = sanitize(input_data)
    safe_output = sanitize(evidence_output)

    # Print clean progress line to console
    console.info(f"[{agent_name}] Step: '{step_name}' | Status: {status} | TripRequest: {trip_request_id}")
    if status == "Failed" and isinstance(output_data, dict):
        code = output_data.get("error_code") or output_data.get("failure_code")
        reason = output_data.get("error") or output_data.get("reason")
        if code or reason:
            console.warning("[%s] TripRequest %s rejected: %s | %s", agent_name, trip_request_id, code or "FAILED", reason or "See the agent audit log.")

    payload = {
        "tripRequestId": trip_request_id,
        "agentName": agent_name,
        "stepName": step_name,
        "stepType": step_type,
        "toolName": tool_name,
        "durationMs": duration_ms,
        "input": bounded_json(safe_input),
        "output": bounded_json(safe_output),
        "status": status,
        "timestamp": now_iso
    }

    try:
        append_record({**payload, "input": safe_input, "output": safe_output})
    except OSError as error:
        console.warning("Could not save local agent evidence: %s", error)

    _post_audit_payload(payload)
    return payload


def _post_audit_payload(payload):
    """Best-effort remote audit transport, isolated for offline unit tests."""
    step_name = payload["stepName"]

    # Send log to backend API
    try:
        url = f"{BACKEND_URL}/api/triprequest/agent-log"
        client = _audit_client.get()
        if client is None:
            with httpx.Client(timeout=httpx.Timeout(5.0, connect=2.0)) as standalone:
                response = standalone.post(url, json=payload, headers=agent_service_headers())
        else:
            response = client.post(url, json=payload, headers=agent_service_headers())
        if response.is_success:
            return payload
        else:
            console.warning(f"Backend returned HTTP {response.status_code} when logging step '{step_name}'")
    except Exception as e:
        # Backend might be offline during standalone agent testing; do not crash
        console.warning(f"Could not connect to backend ({BACKEND_URL}) to persist log: {e}")

    return payload
