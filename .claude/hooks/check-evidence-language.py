#!/usr/bin/env python3
"""External validator for CLAUDE.md's Evidence_Based_Standards.

Deterministic, non-LLM check that the framework's own
`Prohibited_Language` rule (superclaude-core.yml#Evidence_Based_Standards)
was actually respected in the assistant's last reply. Reads the pattern
straight from that YAML file so there is a single source of truth.

Two modes:
  - Stop hook (no args): reads Claude Code's Stop-hook JSON from stdin,
    inspects the transcript's last assistant message, and returns
    {"decision": "block", "reason": ...} if a prohibited term is found
    outside code blocks.
  - Manual/CI (--file PATH): scans a plain text/markdown file, prints a
    human-readable report, exits 1 if anything was found.
"""
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CORE_YML = REPO_ROOT / ".claude" / "shared" / "superclaude-core.yml"


def load_prohibited_terms() -> list[str]:
    """Extract the Prohibited_Language alternation straight from the YAML."""
    text = CORE_YML.read_text(encoding="utf-8")
    match = re.search(r'^Prohibited_Language:\s*"([^"]+)"', text, re.MULTILINE)
    if not match:
        return []
    return [term.strip() for term in match.group(1).split("|") if term.strip()]


def strip_code(text: str) -> str:
    """Drop fenced/inline code so identifiers like `isSecure()` don't trigger."""
    text = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)
    text = re.sub(r"`[^`]*`", " ", text)
    return text


def find_matches(text: str, terms: list[str]) -> list[str]:
    prose = strip_code(text)
    pattern = re.compile(r"\b(" + "|".join(re.escape(t) for t in terms) + r")\b", re.IGNORECASE)
    return sorted({m.group(1).lower() for m in pattern.finditer(prose)})


def last_assistant_text(transcript_path: str) -> str:
    chunks = []
    try:
        with open(transcript_path, encoding="utf-8") as f:
            lines = f.readlines()
    except OSError:
        return ""

    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") != "assistant":
            continue
        content = event.get("message", {}).get("content", [])
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                chunks.append(block.get("text", ""))
        if chunks:
            break
    return "\n".join(chunks)


def run_as_hook() -> None:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return  # never break the session on malformed input

    if payload.get("stop_hook_active"):
        return  # already gave feedback once this turn; avoid a block loop

    transcript_path = payload.get("transcript_path")
    if not transcript_path:
        return

    terms = load_prohibited_terms()
    if not terms:
        return

    text = last_assistant_text(transcript_path)
    matches = find_matches(text, terms)
    if not matches:
        return

    reason = (
        "Evidence_Based_Standards (superclaude-core.yml) flags unproven language in your "
        f"last reply: {', '.join(matches)}. Either back the claim with a specific source/measurement "
        "(testing confirms..., benchmarks show...) or rephrase using Required_Language "
        "(may/could/typically/often) instead of the superlative."
    )
    print(json.dumps({"decision": "block", "reason": reason}))


def run_as_cli(path: str) -> int:
    terms = load_prohibited_terms()
    text = Path(path).read_text(encoding="utf-8")
    matches = find_matches(text, terms)
    if not matches:
        print(f"OK: no prohibited language found in {path}")
        return 0
    print(f"FAIL: {path} uses unproven terms: {', '.join(matches)}")
    return 1


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--file":
        sys.exit(run_as_cli(sys.argv[2]))
    else:
        run_as_hook()
