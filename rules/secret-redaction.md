# Secret Redaction

Drop this file into `.claude/rules/secret-redaction.md`.

- A found secret NEVER appears in full in any output, log, PR or
  ticket: only the first 4 characters + the file location.
- The report points to the path and line, not the value.
- Secret confirmed in git history: rotate FIRST, rewrite history
  after... the order matters: rewriting before rotating leaves the
  credential valid and the leak invisible.
- Applies to the agent AND to humans pasting output into Slack.
