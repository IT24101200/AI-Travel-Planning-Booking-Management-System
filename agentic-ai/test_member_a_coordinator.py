"""Member A / IT24101200: budget strategy, fallback evidence and retry authority."""

import pytest
from agents import coordinator_agent as agent

pytestmark = pytest.mark.member_a


@pytest.mark.parametrize("model_response,mode", [
    (None, "deterministic_fallback"),
    ('{"trip_theme":"Heritage","planning_strategy":"Allow rest days"}', "llm_response"),
])
def test_budget_is_rule_based_and_evidence_identifies_strategy_source(monkeypatch, model_response, mode):
    logs = []
    monkeypatch.setattr(agent, "call_gemini_for_planning", lambda _: model_response)
    monkeypatch.setattr(agent, "log_agent_step", lambda **row: logs.append(row))
    result = agent.coordinator_plan({
        "trip_request_id": 1, "destination_id": 1,
        "start_date": "2026-10-10", "end_date": "2026-10-14",
        "traveller_count": 2, "budget_ceiling": 100000, "currency": "LKR",
    })
    assert result["trip_days"] == 5
    assert result["target_budgets"] == {
        "tours_budget": 35000, "hotels_budget": 45000,
        "transport_budget": 15000, "buffer": 5000,
    }
    assert logs[0]["execution_mode"] == mode
    assert bool(logs[0]["model"]) == bool(model_response)


def test_failed_budget_gets_only_one_retry():
    state = {"validation_result": {"is_valid": False, "error": "Over budget", "error_code": "BUDGET_EXCEEDED"}}
    first = agent.coordinator_retry_evaluator(state)
    assert first["next_action"] == "retry"
    second = agent.coordinator_retry_evaluator({**state, **first})
    assert second["status"] == "Failed"
    assert second["next_action"] == "fail"
