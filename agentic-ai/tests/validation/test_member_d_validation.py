"""Member D / IT24100120: commercial validation stops at staff approval."""

from unittest.mock import Mock
import pytest
from agents.validation_agent import validation_node
from tests.validation.test_validation_agent import _state
from tools import validation_tools

pytestmark = pytest.mark.member_d


def test_valid_proposal_does_not_create_booking_or_charge_customer(monkeypatch):
    create = Mock()
    pay = Mock()
    monkeypatch.setattr(validation_tools, "create_booking", create)
    monkeypatch.setattr(validation_tools, "initiate_payment", pay)
    result = validation_node(_state())
    assert result["status"] == "AwaitingApproval"
    assert result["validation_result"]["checks"]["approval_gate_enforced"]
    create.assert_not_called()
    pay.assert_not_called()


@pytest.mark.parametrize("budget,total", [(949, 950), (1500, 1)])
def test_over_budget_or_manipulated_total_cannot_reach_approval(budget, total):
    state = _state(budget_ceiling=budget)
    state["booking_details"].update(total_cost=total, total_package_cost=total)
    result = validation_node(state)
    assert result["status"] == "ValidationFailed"
    assert not result["validation_result"]["is_valid"]
    assert "plan_json" not in result
