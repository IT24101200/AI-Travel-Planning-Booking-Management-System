import logging
from unittest.mock import patch

from logger import _RedactApiKeys, log_agent_step


def test_http_request_log_redacts_query_credentials():
    record = logging.LogRecord("httpx", logging.INFO, "", 0, 'HTTP Request: %s %s "HTTP/1.1 429"',
        ("POST", "https://generativelanguage.googleapis.com/v1beta/interactions?key=secret-value&mode=test"), None)
    assert _RedactApiKeys().filter(record)
    assert "secret-value" not in record.getMessage()
    assert "key=[REDACTED]&mode=test" in record.getMessage()
    assert "429" in record.getMessage()


def test_failed_agent_step_logs_code_and_reason(caplog):
    with patch("logger.httpx.Client") as client, caplog.at_level(logging.WARNING):
        client.return_value.__enter__.return_value.post.return_value.is_success = True
        log_agent_step(164, "BookingAgent", "Booking Agent failed", status="Failed",
            output_data={"error_code": "TRANSPORT_CATALOGUE_NO_ROUTE", "error": "No transport covers Airport -> Kandy."})
    assert "TRANSPORT_CATALOGUE_NO_ROUTE" in caplog.text
    assert "Airport -> Kandy" in caplog.text


def test_httpx_logger_filter_removes_key_before_handler_receives_record(caplog):
    with caplog.at_level(logging.INFO, logger="httpx"):
        logging.getLogger("httpx").info("HTTP Request: POST https://example.invalid/?key=%s", "another-secret")
    assert "another-secret" not in caplog.text
    assert "key=[REDACTED]" in caplog.text
