from pathlib import Path
from threading import Barrier, Lock
from unittest.mock import patch
import runpy

import pytest

from agents.booking_agent import _inventory_map, INVENTORY_WORKERS


def test_inventory_reads_overlap_with_bounded_workers_and_preserve_order():
    barrier = Barrier(INVENTORY_WORKERS)
    lock = Lock()
    active = 0
    peak = 0

    def read(value):
        nonlocal active, peak
        with lock:
            active += 1
            peak = max(active, peak)
        barrier.wait(timeout=5)
        with lock:
            active -= 1
        return value * 10

    values = list(range(INVENTORY_WORKERS * 2))
    assert _inventory_map(read, values) == [value * 10 for value in values]
    assert peak == INVENTORY_WORKERS


def test_inventory_read_failure_is_not_returned_as_a_partial_catalogue():
    def read(value):
        if value == 1:
            raise RuntimeError("catalogue unavailable")
        return value

    with pytest.raises(RuntimeError, match="catalogue unavailable"):
        _inventory_map(read, range(4))


def test_invalid_request_skips_coordinator_and_inventory_and_has_stage_timings():
    import graph

    with (
        patch.object(graph, "coordinator_plan") as coordinator,
        patch.object(graph, "itinerary_node") as itinerary,
        patch.object(graph, "booking_node") as booking,
        patch("logger.log_agent_step"),
        patch("agents.coordinator_agent.log_agent_step"),
    ):
        result = graph.travel_app.invoke({
            "trip_request_id": 1,
            "start_date": "2026-10-10",
            "end_date": "2026-10-10",
            "traveller_count": 2,
            "requested_destinations": [{"destination_id": 1}],
        })
    assert result["status"] == "Failed"
    coordinator.assert_not_called()
    itinerary.assert_not_called()
    booking.assert_not_called()
    assert set(result["stage_durations_ms"]) == {"PreflightFeasibility", "CoordinatorEvaluator"}
    assert all(value >= 0 for value in result["stage_durations_ms"].values())


def test_manual_booking_demo_does_not_run_during_test_discovery():
    with patch("agents.booking_agent.booking_node") as booking:
        runpy.run_path(str(Path(__file__).with_name("test_run.py")), run_name="test_run")
    booking.assert_not_called()


def test_retried_stage_timing_accumulates_without_changing_node_output():
    import graph

    with patch.object(graph, "perf_counter", side_effect=[1.0, 1.025]):
        result = graph._run_logged_node("BookingAgent", lambda _: {"status": "Planned"}, {
            "stage_durations_ms": {"BookingAgent": 10},
        })
    assert result["status"] == "Planned"
    assert result["stage_durations_ms"]["BookingAgent"] == 35


def test_budget_retry_reuses_theme_and_recomputes_reduced_budgets():
    from agents import coordinator_agent

    with (
        patch.object(coordinator_agent, "call_gemini_for_planning") as llm,
        patch.object(coordinator_agent, "log_agent_step"),
    ):
        result = coordinator_agent.coordinator_plan({
            "destination_id": 1,
            "destination_name": "Colombo",
            "start_date": "2026-10-10",
            "end_date": "2026-10-12",
            "budget_ceiling": 10000,
            "retry_count": 1,
            "plan_summary": {"theme": "Beach getaway", "strategy": "Balanced trip"},
        })
    llm.assert_not_called()
    assert result["plan_summary"]["theme"] == "Beach getaway"
    assert result["plan_summary"]["effective_target_budget"] == 8500
    assert result["target_budgets"]["hotels_budget"] == 3825
