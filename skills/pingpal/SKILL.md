---
name: pingpal
description: Keep the user informed through the PingPal desktop character while you work. Report when work finishes or fails, when a longer job starts, and when you are blocked and need the user to come back to this session. Use whenever the `pingpal` MCP server (tools `notify`, `set_state`, `clear`) is available and you do real work (running commands, editing files, investigating) or need the user's input.
---

# Reporting to PingPal

PingPal is a small character on the user's screen. The user is often in another window, so it tells
them what this session is doing without them watching it. Everything you send appears on screen,
shared with their other AI sessions, so be brief and sparing.

## `source`: required on every call

`source` names this session. Each distinct name is its own entry on the user's screen, with its own
color, tray chip and status.

- Use the title of this session if you know it (for example `Add contributor guide for character packs`).
- Otherwise use a short description of the task or repo (for example `Fix login redirect`), at most 80 characters.
- Choose it once at the start and use **exactly the same string on every call**. A different string
  is a different session to the user. Do not change it when the subtask changes.

## What to call, and when

| Moment | Call |
| --- | --- |
| You start a longer job (more than about a minute) that the user would want to see running | `set_state(source, status="working", text="<what you are doing>")` |
| You finish real work, however short | `set_state(source, status="done", text="<one-line result>")` |
| You failed and cannot continue | `set_state(source, status="error", text="<what failed>")` |
| You are blocked and need the user (a decision, approval, missing information) | `set_state(source, status="needs_input", text="<what you need>")`, then see below |
| The user answered and you resume | `set_state(source, status="working", text="<what you are doing>")` |
| Something mid-task is worth their attention (a milestone, a surprising finding, a decision you made) | `notify(source, text="<one line>")` |
| An earlier message is now wrong or obsolete | `clear(source)`, then send the correct state |
| You stop early with nothing to report | `set_state(source, status="idle")` |

## When you are blocked

1. Call `set_state` with `needs_input` and a one-line reason in `text`. The character flags you and keeps
   waving until the user looks.
2. Put the **full question, with its context and your options**, in your normal reply in this session.
   That is where the user answers. PingPal has no way to answer for them.
3. Then stop. Do not poll, loop, or call any tool waiting for a reply. They will open this session themselves.

## Rules

- **Always report the end of real work.** If you ran commands, edited files or investigated, send
  `done`, `error` or `needs_input` when you stop, however short it was: the user may have looked away.
  Skip PingPal entirely for plain chat answers where you did no work.
- **`working` is for longer jobs.** For a short task, skip it and send only `done`. If you did send
  `working`, always end with `done`, `error` or `needs_input`; never leave `working` hanging.
- **One announcement per event.** `done`, `error` and `needs_input` already pop up a bubble with your
  `text`. Do not also call `notify` for the same thing.
- **Short plain text.** One line, ideally under 100 characters (the limit is 280). No markdown.
- **Nothing sensitive.** No secrets, tokens, private code or personal data: the text is shown on screen
  and kept in a history.
- **Few calls.** A short task needs one (`done`); a long one two to four. Do not narrate steps or
  notify per file or per test.
- **Long tasks.** A `working` chip disappears after 30 minutes without any call from this session. If
  you will run longer, repeat `set_state(working)` with fresh text about every 15 minutes.
- **Priority.** Leave `notify` at its default. Use `low` for chatty extras (they are batched), `high`
  only for what the user must see soon, and `urgent` almost never: it interrupts what they are reading.
  `done`, `error` and `needs_input` choose their own priority.
- **Helpers.** Sub-agents and parallel helpers do not report separately; this session reports for them.
- **If a call fails**, PingPal may not be running. Do not retry in a loop and do not let it derail the
  work. Mention it at most once. If the error says `source` is required, you left it out: add it and
  send once more.

## What the user sees

Your name and `text` in a speech bubble in your color, and a chip above the character with your initial:
a spinning ring for `working`, a check for `done`, a pulsing "!" for `needs_input`, an x for `error`.
The character keeps its attention animation until the user checks the message. `done`, `error` and
`needs_input` chips stay until the user opens the history.

## Examples

```text
set_state(source="Fix login redirect", status="working", text="Reproducing the bug")
notify(source="Fix login redirect", text="Root cause: the redirect drops the query string")
set_state(source="Fix login redirect", status="needs_input", text="Keep the old route or remove it?")
set_state(source="Fix login redirect", status="done", text="Fixed; 12 tests pass, PR is ready")
```
