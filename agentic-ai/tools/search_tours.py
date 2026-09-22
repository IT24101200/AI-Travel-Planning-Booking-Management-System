"""Utilities for searching tours through the backend API."""

import os

import requests
from dotenv import load_dotenv


# Load variables from a .env file into the environment when one is available.
load_dotenv()


def search_tours(destination_id, category=None, max_price=None):
    """Tool: search_tours(destination_id, category, max_price) — queries the
    ASP.NET Core GET /api/tour endpoint to retrieve candidate tours.

    Takes a destination ID and optional category and maximum-price filters.
    Returns a list containing only tours whose status is "Active".
    """
    # Read the backend URL from the environment so it can be changed without
    # editing this file. Use a localhost address for local development.
    backend_base_url = os.getenv("BACKEND_API_URL", "http://localhost:5000")
    endpoint_url = f"{backend_base_url.rstrip('/')}/api/tour"

    # Build the query string one value at a time. Optional values are included
    # only when the caller provides them.
    query_parameters = {}
    if destination_id is not None:
        query_parameters["destinationId"] = destination_id
    if category is not None:
        query_parameters["category"] = category
    if max_price is not None:
        query_parameters["maxPrice"] = max_price

    try:
        # Send the GET request. The timeout prevents the program from waiting
        # forever when the backend cannot be reached.
        response = requests.get(
            endpoint_url,
            params=query_parameters,
            timeout=10,
        )

        # Turn non-success HTTP responses, such as 404 or 500, into an error
        # that is handled below instead of crashing the caller.
        response.raise_for_status()

        # Convert the JSON response into normal Python objects.
        tours = response.json()

        # The endpoint should return a JSON list. If it does not, return an
        # empty list rather than failing later while filtering the results.
        if not isinstance(tours, list):
            print(
                "Error searching tours: the backend returned an unexpected "
                "response format."
            )
            return []

        # Keep only dictionary objects with an exact status value of "Active".
        return [
            tour
            for tour in tours
            if isinstance(tour, dict) and tour.get("status") == "Active"
        ]
    except ValueError as error:
        # response.json() raises ValueError when the response is not valid JSON.
        print(f"Error searching tours: the backend returned invalid JSON ({error}).")
        return []
    except requests.RequestException as error:
        # This handles connection errors, timeouts, and non-success responses.
        print(f"Error searching tours: the backend request failed ({error}).")
        return []