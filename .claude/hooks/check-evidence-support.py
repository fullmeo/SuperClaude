#!/usr/bin/env python3
"""Level-3 (semantic, best-effort) external validator: cited but unsupported evidence.

This is the level we already flagged as structurally out of reach: no
regex can confirm a citation is real or that "benchmarks show X" is
actually true. What IS checkable without a second LLM judgment is a
weaker, purely syntactic proxy: does a sentence that *claims* the
Evidence_Requirements phrasing (superclaude-core.yml#Evidence_Based_Standards
-- "testing confirms...", "benchmarks show...", etc.) carry ANY concrete
marker next to it (a URL, a number/percentage, a code span, a markdown
link)? If not, the claim is asserting evidence-based language while
citing nothing a reader could check.

This catches zero-effort evidence-washing ("testing confirms this is
fast") but proves nothing about sentences that DO cite something -- the
citation could still be fabricated or irrelevant. Because of that false
sense of certainty risk, this NEVER blocks: it only ever returns a
`systemMessage` (visible, non-blocking) so a human stays the actual judge.

Two modes:
  - Stop hook (no args): warns (never blocks) about the assistant's last
    reply.
  - Manual/CI (--file PATH): prints a human-readable report; exit code
    is always 0 (advisory only, not a pass/fail gate).
"""
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CORE_YML = REPO_ROOT / ".claude" / "shared" / "superclaude-core.yml"

MARKER_PATTERN = re.compile(
    r"https?://\S+"          # URL
    r"|\[[^\]]+\]\([^)]+\)"  # markdown link
    r"|`[^`]+`"              # code span
    r"|\d+(?:\.\d+)?\s?%"    # percentage
    r"|\b\d+(?:\.\d+)?(?:x|ms|s|kb|mb|gb)\b",  # measurement-shaped number
    re.IGNORECASE,
)


def load_evidence_phrases() -> list[str]:
    text = CORE_YML.read_text(encoding="utf-8")
    match = re.search(r'^Evidence_Requirements:\s*"([^"]+)"', text, re.MULTILINE)
    if not match:
        return []
    return [p.strip() for p in match.group(1).split("|") if p.strip()]


def split_sentences(text: str) -> list[str]:
    text = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)  # skip fenced code as "sentences"
    return re.split(r"(?<=[.!?])\s+", text)


def find_unsupported_claims(text: str, phrases: list[str]) -> list[str]:
    pattern = re.compile("|".join(re.escape(p) for p in phrases), re.IGNORECASE)
    unsupported = []
    for sentence in split_sentences(text):
        if pattern.search(sentence) and not MARKER_PATTERN.search(sentence):
            unsupported.append(sentence.strip())
    return unsupported


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
        return

    transcript_path = payload.get("transcript_path")
    if not transcript_path:
        return

    phrases = load_evidence_phrases()
    if not phrases:
        return

    text = last_assistant_text(transcript_path)
    unsupported = find_unsupported_claims(text, phrases)
    if not unsupported:
        return

    message = (
        "Advisory (not blocking) -- Evidence_Requirements phrasing used without a nearby "
        "concrete marker (URL, number, code, link): " + " | ".join(unsupported[:3])
    )
    print(json.dumps({"systemMessage": message}))


def run_as_cli(path: str) -> int:
    phrases = load_evidence_phrases()
    text = Path(path).read_text(encoding="utf-8")
    unsupported = find_unsupported_claims(text, phrases)
    if not unsupported:
        print(f"OK: every evidence-phrase in {path} has a nearby concrete marker")
    else:
        print(f"ADVISORY: {path} has {len(unsupported)} unsupported evidence claim(s):")
        for s in unsupported:
            print(f"  - {s}")
    return 0  # advisory only, never a hard failure


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--file":
        sys.exit(run_as_cli(sys.argv[2]))
    else:
        run_as_hook()
