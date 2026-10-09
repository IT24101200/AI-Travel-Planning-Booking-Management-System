"""Evidence must survive truncation and transport failure without leaking keys."""

import json
from concurrent.futures import ThreadPoolExecutor

import evidence
import logger


def test_full_local_output_and_parseable_database_summary_share_run(tmp_path, monkeypatch):
    monkeypatch.setenv("AGENT_EVIDENCE_DIR", str(tmp_path))
    with logger.audit_log_session():
        first = logger.log_agent_step(1, "BookingAgent", "Selected inventory",
            input_data={"authorization": "secret", "nested": {"api_key": "hidden"}},
            output_data={"rooms": [{"room_id": i} for i in range(2000)]},
            reason="Use only available rooms and stay within the trip budget.")
        second = logger.log_agent_step(1, "ValidationAgent", "Validated proposal")
    stored = [json.loads(line) for line in next(tmp_path.glob("*.jsonl")).read_text().splitlines()]
    assert len(stored) == 2
    assert len(stored[0]["output"]["rooms"]) == 2000
    assert stored[0]["input"]["nested"]["api_key"] == "[REDACTED]"
    assert stored[0]["output"]["_evidence"]["context"] == "test"
    assert len(first["output"]) <= 4000
    summary = json.loads(first["output"])
    assert summary["_truncated"]
    assert summary["_evidence"]["run_id"] == json.loads(second["output"])["_evidence"]["run_id"]
    report = evidence.render_report(stored, "test-digest")
    assert '"room_id": 1999' in report
    assert "hidden" not in report
    assert "Evidence context: test" in report


def test_concurrent_runs_have_separate_evidence_files(tmp_path, monkeypatch):
    monkeypatch.setenv("AGENT_EVIDENCE_DIR", str(tmp_path))
    def run(trip):
        with logger.audit_log_session():
            logger.log_agent_step(trip, "CoordinatorAgent", "Start")
            logger.log_agent_step(trip, "BookingAgent", "Select")
    with ThreadPoolExecutor(max_workers=2) as executor:
        list(executor.map(run, [1, 2]))
    files = list(tmp_path.glob("*.jsonl"))
    assert len(files) == 2
    assert all(len(path.read_text().splitlines()) == 2 for path in files)
    assert logger._audit_run_id.get() is None


def test_disk_failure_does_not_fail_planning(monkeypatch):
    def fail(_):
        raise OSError("Read-only disk")
    monkeypatch.setattr(logger, "append_record", fail)
    assert logger.log_agent_step(1, "BookingAgent", "Select")["status"] == "Success"


def test_report_does_not_invent_model_usage_for_legacy_logs():
    report = evidence.render_report([{"agentName": "ItineraryAgent", "output": "cut off {"}], "digest")
    assert "Execution: not recorded" in report
    assert "Not recorded in this legacy log" in report
    assert '"_unparsed": true' in report


def test_query_keys_and_bearer_tokens_are_redacted_recursively():
    clean = evidence.sanitize({"notes": ["https://example.test/?key=abc&other=1", "Bearer xyz.123"],
                               "X-Agent-Service-Key": "internal"})
    # Header spellings and API-key query values are credentials, not evidence.
    assert "abc" not in json.dumps(clean)
    assert "xyz.123" not in json.dumps(clean)
    assert "internal" not in json.dumps(clean)


def test_export_command_accepts_backend_json_array(tmp_path, monkeypatch):
    source = tmp_path / "logs.json"
    target = tmp_path / "report.md"
    source.write_text(json.dumps([{"agentName": "BookingAgent", "input": '{"api_key":"secret"}',
                                  "output": '{"selected_room":{"room_id":42}}'}]))
    monkeypatch.setattr("sys.argv", ["evidence.py", "--input", str(source), "--output", str(target)])
    evidence.main()
    report = target.read_text(encoding="utf-8")
    assert '"room_id": 42' in report
    assert "secret" not in report
