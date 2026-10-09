"""Preserve observable agent decisions and export them as a readable report.

Records are application evidence, not model chain-of-thought. Local JSONL keeps
the full sanitized output; the backend receives a bounded, valid JSON summary.
"""

import argparse
import hashlib
import json
import os
import re
from pathlib import Path
from threading import Lock

_write_lock = Lock()
_PRIVATE_KEYS = {
    "authorization", "accesstoken", "authtoken", "apikey", "password",
    "secret", "agentserviceapikey", "geminiapikey", "googleapikey",
    "aimlapikey", "token", "refreshtoken", "xagentservicekey",
}


def sanitize(value):
    """Remove credential fields recursively before either storage destination."""
    if isinstance(value, dict):
        return {
            str(key): "[REDACTED]" if re.sub(r"[^a-z]", "", str(key).lower()) in _PRIVATE_KEYS
            else sanitize(item)
            for key, item in value.items()
        }
    if isinstance(value, (list, tuple)):
        return [sanitize(item) for item in value]
    if isinstance(value, str):
        value = re.sub(r"([?&](?:key|api_key|access_token)=)[^&\s\"']+", r"\1[REDACTED]", value, flags=re.I)
        return re.sub(r"Bearer\s+[A-Za-z0-9._~+/=-]+", "Bearer [REDACTED]", value, flags=re.I)
    return value


def bounded_json(value, limit=4000):
    """Keep database JSON parseable and disclose when the full output is local."""
    if value is None:
        return None
    encoded = json.dumps(value, ensure_ascii=True, default=str)
    if len(encoded) <= limit:
        return encoded
    summary = {"_truncated": True, "original_characters": len(encoded)}
    if isinstance(value, dict) and "_evidence" in value:
        summary["_evidence"] = value["_evidence"]
    summary["preview"] = ""
    # JSON escaping can expand a preview, so enforce the serialized size.
    preview = encoded[:limit // 2]
    while preview:
        summary["preview"] = preview
        result = json.dumps(summary, ensure_ascii=True, default=str)
        if len(result) <= limit:
            return result
        preview = preview[:len(preview) // 2]
    return json.dumps({"_truncated": True, "original_characters": len(encoded)})


def append_record(record):
    """Append one full record; callers handle disk failures without losing plans."""
    directory = Path(os.getenv("AGENT_EVIDENCE_DIR") or Path(__file__).parent / "evidence" / "runs")
    directory.mkdir(parents=True, exist_ok=True)
    # IDs are generated internally; never use user text as a file path.
    run_id = record["output"]["_evidence"]["run_id"]
    path = directory / f"{run_id}.jsonl"
    with _write_lock, path.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(sanitize(record), ensure_ascii=True, default=str) + "\n")


def _decode(value):
    if isinstance(value, str):
        try:
            return sanitize(json.loads(value))
        except ValueError:
            return {"legacy_text": value, "_unparsed": True}
    return value


def render_report(records, source_digest):
    """Render saved evidence without inferring missing model usage or outcomes."""
    lines = ["# Agent usage evidence", "", f"Source SHA-256: `{source_digest}`", "",
             "This report describes recorded inputs, decision reasons and outputs. "
             "It does not certify a live deployment or expose private model reasoning.", ""]
    for index, raw in enumerate(records, 1):
        row = sanitize(raw)
        output = _decode(row.get("output"))
        metadata = output.get("_evidence", {}) if isinstance(output, dict) else {}
        lines.extend([
            f"## {index}. {row.get('agentName', 'Unknown')} — {row.get('stepName', 'Unknown')}", "",
            f"- Trip: {row.get('tripRequestId', 'Unknown')}; run: {metadata.get('run_id', 'not recorded')}",
            f"- Time: {row.get('timestamp', 'Unknown')}; status: {row.get('status', 'Unknown')}",
            f"- Evidence context: {metadata.get('context', 'not recorded; verify source before claiming a live run')}",
            f"- Execution: {metadata.get('execution_mode', 'not recorded')}; model: {metadata.get('model') or 'not recorded'}",
            f"- Tool: {metadata.get('tool_name') or row.get('toolName') or 'none recorded'}; duration: {metadata.get('duration_ms', row.get('durationMs'))} ms",
            f"- Reason: {metadata.get('reason') or 'Not recorded in this legacy log.'}", "",
        ])
        for label, value in (("Input", _decode(row.get("input"))), ("Output", output)):
            # A long fence keeps arbitrary customer text inside the code block.
            text = json.dumps(value, indent=2, ensure_ascii=True, default=str)
            longest = max((len(match.group()) for match in re.finditer(r"`+", text)), default=0)
            fence = "`" * max(3, longest + 1)
            lines.extend([f"### {label}", "", f"{fence}json", text, fence, ""])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Local JSONL run or JSON array from GET /api/triprequest/{id}/logs")
    parser.add_argument("--output", type=Path, required=True, help="Markdown report destination")
    args = parser.parse_args()
    source = args.input.read_bytes()
    text = source.decode("utf-8-sig")
    records = json.loads(text) if text.lstrip().startswith("[") else [json.loads(line) for line in text.splitlines() if line.strip()]
    if not records or not all(isinstance(row, dict) for row in records):
        parser.error("Expected one or more agent log objects.")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render_report(records, hashlib.sha256(source).hexdigest()), encoding="utf-8")
    print(f"Wrote {len(records)} evidence records to {args.output}")


if __name__ == "__main__":
    main()
