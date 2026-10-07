"""
logger.py - Shared Agent Audit Logger
Logs every reasoning cycle and decision step of each agent to the backend database.
If the backend is not running, falls back to local console logging.
"""

import os
import json
import logging
from datetime import datetime, timezone
import httpx
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure local console logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s"
)
console = logging.getLogger("AgentLogger")

def _normalise_backend_url(value: str) -> str:
    normalised = value.rstrip("/")
    return normalised[:-4] if normalised.lower().endswith("/api") else normalised


BACKEND_URL = _normalise_backend_url(
    os.getenv("BACKEND_URL") or os.getenv("BACKEND_API_URL") or "http://localhost:5138"
)
AGENT_SERVICE_API_KEY = os.getenv("AGENT_SERVICE_API_KEY", "").strip()


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
    duration_ms: int = None
):
    """
    Sends an agent audit log entry to the ASP.NET Core backend API.
    Persists to the PostgreSQL AgentLogs table.
    """
    now_iso = datetime.now(timezone.utc).isoformat()
    formatted_input = format_payload(input_data)
    formatted_output = format_payload(output_data)

    # Print clean progress line to console
    console.info(f"[{agent_name}] Step: '{step_name}' | Status: {status} | TripRequest: {trip_request_id}")

    payload = {
        "tripRequestId": trip_request_id,
        "agentName": agent_name,
        "stepName": step_name,
        "stepType": step_type,
        "toolName": tool_name,
        "durationMs": duration_ms,
        "input": formatted_input[:4000] if formatted_input else None,
        "output": formatted_output[:4000] if formatted_output else None,
        "status": status,
        "timestamp": now_iso
    }

    # Send log to backend API
    try:
        url = f"{BACKEND_URL}/api/triprequest/agent-log"
        with httpx.Client(timeout=httpx.Timeout(5.0, connect=2.0)) as client:
            response = client.post(url, json=payload, headers=agent_service_headers())
            if response.is_success:
                return payload
            else:
                console.warning(f"Backend returned HTTP {response.status_code} when logging step '{step_name}'")
    except Exception as e:
        # Backend might be offline during standalone agent testing; do not crash
        console.warning(f"Could not connect to backend ({BACKEND_URL}) to persist log: {e}")

    return payload
