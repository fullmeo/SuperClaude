#!/usr/bin/env python3
"""Level-2 (structural) external validator: MCP_Preferences vs actual usage.

superclaude-personas.yml declares, per persona, which MCP servers to
avoid (e.g. architect: "Avoid Magic"; backend: "Avoid Magic for server
logic"). This hook checks, for the persona flag(s) mentioned by the user
in the current turn, whether a tool matching an avoided server name was
actually invoked. It is deliberately conservative: an "Avoid X unless Y"
clause is only WARNED about (never blocked), because verifying the "Y"
exception is a semantic judgment this script cannot make — it only
blocks on unconditional "Avoid X" clauses, which are unambiguous.

Two modes:
  - Stop hook (no args): reads Claude Code's Stop-hook JSON from stdin,
    scans the transcript for the current turn.
  - Manual/CI (--simulate PERSONA_FLAG TOOL1,TOOL2,...): exercises the
    same logic against a hand-built scenario, no transcript needed.
"""
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PERSONAS_YML = REPO_ROOT / ".claude" / "shared" / "superclaude-personas.yml"


def load_personas() -> dict[str, str]:
    """Map '--persona-x' -> its raw MCP_Preferences string."""
    text = PERSONAS_YML.read_text(encoding="utf-8")
    section = text.split("## Collaboration_Patterns")[0]
    personas = {}
    for block in re.split(r"\n\s*\n", section):
        flag_m = re.search(r'Flag:\s*"(--persona-[\w-]+)"', block)
        mcp_m = re.search(r'MCP_Preferences:\s*"([^"]+)"', block)
        if flag_m and mcp_m:
            personas[flag_m.group(1)] = mcp_m.group(1)
    return personas


def parse_avoid_clauses(mcp_pref: str) -> list[dict]:
    """Extract each 'Avoid ...' clause: which servers, and whether it's
    qualified ('for ...'/'unless ...'). A qualifier means resolving
    whether it applies needs semantic judgment ("is this actually server
    logic?"), so those clauses can only ever be warned about, never
    blocked -- only a bare 'Avoid X' with no qualifier is unambiguous."""
    clauses = []
    for part in mcp_pref.split("|"):
        part = part.strip()
        if not re.match(r"(?i)avoid\b", part):
            continue
        rest = re.sub(r"(?i)^avoid\s+", "", part)
        qualified = bool(re.search(r"(?i)\s+(for|unless)\s+", rest))
        servers_part = re.split(r"(?i)\s+for\s+|\s+unless\s+", rest, maxsplit=1)[0]
        servers = [s.strip() for s in re.split(r"[/,]|\s+and\s+", servers_part) if s.strip()]
        clauses.append({"servers": servers, "qualified": qualified, "raw": part})
    return clauses


def find_matches(persona_flag: str, mcp_pref: str, tool_names: set[str]) -> tuple[list[str], list[str]]:
    """Returns (hard_violations, advisory_warnings)."""
    hard, advisory = [], []
    for clause in parse_avoid_clauses(mcp_pref):
        for server in clause["servers"]:
            for tool in tool_names:
                if server.lower() in tool.lower():
                    msg = (
                        f"--persona-{persona_flag} declares '{clause['raw']}' "
                        f"(superclaude-personas.yml), but tool `{tool}` was used this turn."
                    )
                    (advisory if clause["qualified"] else hard).append(msg)
    return hard, advisory


def scan_current_turn(transcript_path: str) -> tuple[set[str], set[str]]:
    tool_names: set[str] = set()
    persona_flags: set[str] = set()
    try:
        with open(transcript_path, encoding="utf-8") as f:
            lines = f.readlines()
    except OSError:
        return tool_names, persona_flags

    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        etype = event.get("type")
        content = event.get("message", {}).get("content", [])

        if etype == "assistant" and isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") == "tool_use":
                    name = block.get("name")
                    if name:
                        tool_names.add(name)
            continue

        if etype == "user":
            if isinstance(content, str):
                for flag in re.findall(r"--persona-([\w-]+)", content):
                    persona_flags.add(flag.lower())
                break
            if isinstance(content, list):
                text_blocks = [b for b in content if isinstance(b, dict) and b.get("type") == "text"]
                has_tool_result = any(isinstance(b, dict) and b.get("type") == "tool_result" for b in content)
                for b in text_blocks:
                    for flag in re.findall(r"--persona-([\w-]+)", b.get("text", "")):
                        persona_flags.add(flag.lower())
                if text_blocks and not has_tool_result:
                    break  # reached the human message that opened this turn
    return tool_names, persona_flags


def run_as_hook() -> None:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return

    if payload.get("stop_hook_active"):
        return

    transcript_path = payload.get("transcript_path")
    if not transcript_path:
        return

    tool_names, persona_flags = scan_current_turn(transcript_path)
    if not persona_flags or not tool_names:
        return

    personas = load_personas()
    hard, advisory = [], []
    for flag in persona_flags:
        pref = personas.get(f"--persona-{flag}")
        if pref:
            h, a = find_matches(flag, pref, tool_names)
            hard.extend(h)
            advisory.extend(a)

    if hard:
        reason = "MCP_Persona alignment check failed:\n" + "\n".join(f"- {v}" for v in hard)
        if advisory:
            reason += "\n\nAlso qualified (not verified, advisory only):\n" + "\n".join(f"- {v}" for v in advisory)
        print(json.dumps({"decision": "block", "reason": reason}))
    elif advisory:
        message = "Advisory (qualified, not verified): " + " | ".join(advisory)
        print(json.dumps({"systemMessage": message}))


def run_as_cli(persona_flag: str, tools_csv: str) -> int:
    personas = load_personas()
    key = f"--persona-{persona_flag}"
    pref = personas.get(key)
    if not pref:
        print(f"Unknown persona flag: {key}")
        return 2
    tool_names = {t.strip() for t in tools_csv.split(",") if t.strip()}
    hard, advisory = find_matches(persona_flag, pref, tool_names)
    if not hard and not advisory:
        print(f"OK: no MCP_Preferences match for {key} with tools {sorted(tool_names)}")
        return 0
    if hard:
        print(f"FAIL: {key}")
        for v in hard:
            print(f"  - {v}")
    if advisory:
        print(f"ADVISORY (qualified, not verified) for {key}:")
        for v in advisory:
            print(f"  - {v}")
    return 1 if hard else 0


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--simulate":
        sys.exit(run_as_cli(sys.argv[2], sys.argv[3]))
    else:
        run_as_hook()
