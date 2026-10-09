# Member C test evidence (mocked services)

Source: `test_member_c_booking.py::test_model_ids_are_checked_and_model_prices_are_replaced[20-30-None]`. Catalogue and model responses were mocked; this is not a live AI-provider execution.

Source SHA-256: `2302001383267b636ce04fbc72f0679c3ce0d57d72ca7d19bb7688d26acf5db1`

This report describes recorded inputs, decision reasons and outputs. It does not certify a live deployment or expose private model reasoning.

## 1. BookingAgent — Assembled priced booking package

- Trip: 3; run: b6b7e568f6d643d1946d58ce27b9af0d
- Time: 2026-10-09T23:02:30.575334+00:00; status: Success
- Evidence context: test
- Execution: llm_response; model: gpt-4o-mini (AIML API)
- Tool: none recorded; duration: None ms
- Reason: Select available catalogue inventory; restore trusted prices and recalculate tours per traveller, rooms per night and transport per traveller.

### Input

```json
null
```

### Output

```json
{
  "selected_room": {
    "hotel_id": 10,
    "hotel_name": "Test Hotel",
    "room_id": 20,
    "room_type": null,
    "price_per_night": 3000,
    "currency": "LKR"
  },
  "selected_transport": {
    "transport_id": 30,
    "type": null,
    "provider": null,
    "route_from": null,
    "route_to": null,
    "departure_time": null,
    "arrival_time": null,
    "price": 1000,
    "currency": "LKR"
  },
  "itinerary": {
    "schedule": [
      {
        "items": [
          {
            "tour_id": 40,
            "price": 500
          }
        ]
      }
    ]
  },
  "total_package_cost": 12000.0,
  "currency": "LKR",
  "total_cost": 12000.0,
  "_evidence": {
    "schema_version": 1,
    "context": "test",
    "run_id": "b6b7e568f6d643d1946d58ce27b9af0d",
    "reason": "Select available catalogue inventory; restore trusted prices and recalculate tours per traveller, rooms per night and transport per traveller.",
    "execution_mode": "llm_response",
    "model": "gpt-4o-mini (AIML API)",
    "step_type": "Plan",
    "tool_name": null,
    "duration_ms": null
  }
}
```
