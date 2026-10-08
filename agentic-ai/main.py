"""
main.py - FastAPI HTTP Service for Agentic AI Subsystem
Exposes REST endpoints for the ASP.NET Core backend to trigger multi-agent workflows.
"""

import os
import logging
import uvicorn
from fastapi import FastAPI, BackgroundTasks, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any

from graph import run_travel_planning_pipeline

logger = logging.getLogger("AgentService")

app = FastAPI(
    title="AI Travel Planning Multi-Agent Subsystem",
    version="1.0.0",
    description="Student A - Coordinator Agent & LangGraph Multi-Agent Travel Planner"
)

# Enable CORS for local testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class RequestedDestination(BaseModel):
    destination_id: int
    destination_name: Optional[str] = ""
    order: int = 0


class TripPipelineRequest(BaseModel):
    trip_request_id: int = Field(..., description="Unique ID of the TripRequest from backend")
    customer_id: Optional[str] = Field("Customer", description="Customer ID")
    destination_id: Optional[int] = None
    destination_name: Optional[str] = Field("Destination", description="Destination name")
    destination_ids: list[int] = Field(default_factory=list)
    requested_destinations: Optional[list[RequestedDestination]] = None
    raw_request_text: Optional[str] = Field("", description="Raw customer request notes")
    revision_feedback: Optional[str] = Field(None, description="Human travel-agent feedback for a revision run")
    start_date: str = Field(..., description="Start date in ISO format")
    end_date: str = Field(..., description="End date in ISO format")
    traveller_count: int = Field(1, description="Number of travellers")
    budget_ceiling: float = Field(..., description="Budget ceiling")
    currency: str = Field("USD", description="Currency code")
    airport_pickup: bool = False
    airport_code: str = Field("CMB", pattern="^(CMB|HRI)$")
    airport_arrival_time: str = Field("08:00", pattern=r"^(?:[01]\d|2[0-3]):[0-5]\d(?::00)?$")
    retry_count: Optional[int] = Field(0, description="Initial retry count")
    preferred_activities: Optional[list[str]] = Field(default_factory=list)


@app.get("/")
@app.get("/health")
def health_check():
    """Health check endpoint for ASP.NET backend to verify agent service availability."""
    gemini_key_present = bool(os.getenv("GEMINI_API_KEY", "").strip())
    return {
        "status": "healthy",
        "service": "Agentic AI Multi-Agent Service",
        "coordinator": "Student A - Coordinator Agent",
        "llm_configured": gemini_key_present,
        "llm_provider": "Google Gemini" if gemini_key_present else "Rule-based Fallback (Set GEMINI_API_KEY to activate Gemini)"
    }


@app.post("/run-pipeline")
def run_pipeline_sync(payload: TripPipelineRequest):
    """
    Synchronously triggers the LangGraph multi-agent planning pipeline.
    Returns complete plan JSON and final status.
    """
    try:
        input_data = payload.model_dump()
        result = run_travel_planning_pipeline(input_data)
        return {
            "success": True,
            "trip_request_id": payload.trip_request_id,
            "status": result.get("status"),
            "retry_count": result.get("retry_count", 0),
            "failure_reason": result.get("failure_reason"),
            "plan_json": result.get("plan_json")
        }
    except Exception:
        logger.exception("Synchronous pipeline execution failed for TripRequest #%s", payload.trip_request_id)
        raise HTTPException(status_code=500, detail="Pipeline execution failed. Please retry.")


@app.post("/run-pipeline-async")
def run_pipeline_async(payload: TripPipelineRequest, background_tasks: BackgroundTasks):
    """
    Asynchronously triggers the planning pipeline in the background (Option A fire-and-forget).
    Immediately returns HTTP 202 Accepted. Updates the backend upon completion.
    """
    logger.info("/run-pipeline-async received for TripRequest #%s", payload.trip_request_id)
    input_data = payload.model_dump()
    background_tasks.add_task(run_travel_planning_pipeline, input_data)
    return JSONResponse(
        status_code=202,
        content={
            "success": True,
            "message": f"Trip planning pipeline accepted for request #{payload.trip_request_id}.",
            "trip_request_id": payload.trip_request_id,
            "status": "Planning",
        },
    )


if __name__ == "__main__":
    port = int(os.getenv("PORT", 8005))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
