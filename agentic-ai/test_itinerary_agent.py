# Manual test script that I will run myself from the terminal.

import json

from agents.itinerary_agent import build_itinerary


# Sample trip request matching the itinerary agent's expected input contract.
trip_request = {
    "trip_request_id": 101,
    "destination_id": 2,
    "destination_name": "Kandy",
    "start_date": "2026-10-01",
    "end_date": "2026-10-05",
    "traveller_count": 2,
    "budget_ceiling": 150000.00,
        "preferred_activities": ["Heritage", "Safari"],
}


if __name__ == "__main__":
    result = build_itinerary(trip_request)
    print(json.dumps(result, indent=2))
