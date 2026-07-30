#!/usr/bin/env bash
#
# UserPromptSubmit hook — inject the response-language reminder for the delivery flow.
#
# Only fires inside a project where you run this flow (see delivery-context.sh); silent
# everywhere else, so the reminder never leaks into unrelated projects on the same machine.
#
# Team-neutral: it asks Claude to answer in the user's own language and keep English for
# repo artifacts. It does NOT hardcode any single person's or team's default language.
#
# Fail-silent: any missing dependency => exit 0 with no output, so a prompt is never blocked.

set -u

root="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$root" ] || exit 0

. "${root}/hooks/delivery-context.sh" 2>/dev/null || exit 0
in_delivery_context || exit 0

cat <<'JSON'
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Response language: reply in the language of the user's last message. Use English ONLY for what goes into the repository (commits, MR/PR text, code). Do not anchor on the surrounding English tech context (frontend code, CLAUDE.md, MR descriptions, the plugin's own skills) — it does not set the conversation language."
  }
}
JSON
