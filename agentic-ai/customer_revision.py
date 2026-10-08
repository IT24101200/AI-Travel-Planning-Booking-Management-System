"""Apply the backend's dated hotel and per-leg transport instructions."""

def room_requested(revision, room_id, check_in, check_out):
    if not revision:
        return True
    # Every occupied night must use the room selected for that original stay.
    from datetime import date, timedelta
    night = date.fromisoformat(check_in)
    end = date.fromisoformat(check_out)
    while night < end:
        if not any(pin.get("room_id") == room_id and pin["check_in"] <= night.isoformat() < pin["check_out"]
                   for pin in revision.get("rooms", [])):
            return False
        night += timedelta(days=1)
    return True


def reserved_quantity(revision, key, inventory_id, check_in=None, check_out=None):
    return sum(item.get("quantity", 0) for item in revision.get("reserved_items", [])
               if item.get(key) == inventory_id and (check_in is None or
                   (item.get("check_in") and item.get("check_out") and
                    item["check_in"] <= check_in and item["check_out"] >= check_out)))


def transport_requested(revision, option):
    if not revision:
        return True
    return any(pin.get("transport_option_id") == option["transport_id"] and
               pin.get("leg_index") == option.get("leg_index") for pin in revision.get("transports", []))
