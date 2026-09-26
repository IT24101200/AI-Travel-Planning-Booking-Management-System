import os
import json
from agents.booking_agent import booking_node

# We mock the exact state that Agent A and Agent B would have output.
# This allows us to test YOUR Agent C in isolation without worrying about their API keys!
mock_state = {
    "trip_request_id": 999,
    "customer_id": "Cust123",
    "destination_id": 1,
    "destination_name": "Colombo",
    "start_date": "2026-10-01",
    "end_date": "2026-10-05",
    "traveller_count": 2,
    "budget_ceiling": 2000.0,
    "currency": "USD",
    "itinerary": {
        "itinerary_id": None,
        "total_estimated_cost": 150.0,
        "total_cost": 150.0,
        "currency": "LKR",
        "schedule": [
            {
                "day_number": 1,
                "items": [
                    {
                        "tour_id": 101,
                        "tour_name": "Colombo Cultural Heritage Walk",
                        "start_time": "09:00:00",
                        "end_time": "12:00:00",
                        "price": 45.0
                    }
                ]
            }
        ]
    }
}

print("Running ONLY Booking Agent (Student C)...")
print("=========================================")
result_state = booking_node(mock_state)

print("\n--- AGENT C COMPLETED ---")
print("\nFinal Booking Details (Your JSON Output):")
print(json.dumps(result_state.get("booking_details"), indent=2))
