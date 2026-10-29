#!/usr/bin/env python3
"""UserPromptSubmit hook: title sessions that start with a slash command.

Claude Code skips its automatic title for slash-command prompts, so sessions
launched as `/skill args` stay titled "Claude Code" until a plain prompt.
"""
import json
import sys

MAX_TITLE = 60


def main() -> None:
    event = json.load(sys.stdin)
    prompt = (event.get("prompt") or "").strip()
    if event.get("session_title") or not prompt.startswith("/"):
        return
    try:
        with open(event.get("transcript_path") or "", encoding="utf-8") as transcript:
            if any('"type":"ai-title"' in line for line in transcript):
                return
    except OSError:
        pass

    title = " ".join(prompt[1:].split())
    if len(title) > MAX_TITLE:
        title = title[: MAX_TITLE - 1].rstrip() + "…"
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "UserPromptSubmit",
                    "sessionTitle": title,
                }
            }
        )
    )


if __name__ == "__main__":
    main()
