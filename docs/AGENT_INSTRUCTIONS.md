# Teaching your AI to use PingPal

PingPal only helps if your AI sessions call it at the right moments, without spamming you. The server
already sends short usage instructions during the MCP handshake, but some clients do not show those
to the model, so add your own. There are two ways, and **the best setup uses both**:

| | What it is | Reliability |
| --- | --- | --- |
| **The snippet** (below) | A short block in an always-on instructions file | Read in every session, so it is what makes the AI actually call PingPal |
| **The skill** (`skills/pingpal/SKILL.md`) | A complete guide: what to call when, how to name itself, how to ask for you, what to avoid | The model decides whether to load a skill, and often doesn't, so on its own it triggers unreliably. Good for detail |

Put the snippet in your always-on instructions and install the skill beside it; the snippet points the AI
to the skill for more. If you only do one thing, do the snippet.

Both come with the release zip (`skills\pingpal\` and this file) and live in the repo.

## The skill

A skill is a folder containing a `SKILL.md` (YAML frontmatter with `name` and `description`, then
Markdown). Copy the `pingpal` folder from `skills/` to where your tool looks for skills.

```powershell
# Per user (all projects). Check which of these folders already exists on your machine and use that one:
#   GitHub Copilot app / CLI   ~/.copilot/skills/
#   some other installs        ~/.agents/skills/
Copy-Item -Recurse skills\pingpal $HOME\.copilot\skills\

# Per project (shared with your team, commit it):
#   GitHub Copilot  .github/skills/pingpal/SKILL.md
#   Claude Code     .claude/skills/pingpal/SKILL.md   (per user: ~/.claude/skills/pingpal/)
```

Folder names differ between tools and versions: if the skill does not show up, look for where your
tool's other skills live, or check its documentation. The file format is the same everywhere. Start a new
session afterwards: skills are picked up when a session starts.

## The snippet

Paste this into your always-on instructions: `~/.copilot/copilot-instructions.md` (GitHub Copilot, all
your projects), `.github/copilot-instructions.md` (Copilot, per repository), `CLAUDE.md` (Claude Code),
`AGENTS.md` (Codex and others), or your tool's user-level instructions file:

```markdown
## PingPal (desktop notifications)

Use the `pingpal` MCP server to keep me posted while you work. It has three tools: `notify`,
`set_state` and `clear`. If they are not directly callable (listed by name only), your first tool call
must be `tool_search_tool` with pattern `pingpal`. Every call needs `source`: the title of this
session if you know it, otherwise a short description of the task (up to 80 characters), exactly the
same on every call.

- This applies to EVERY request, however small. You cannot know in advance how long a task will take,
  so there is no "real work" threshold and no exemption for chat answers.
- Your first tool call is the `tool_search_tool` search if the tools are deferred, followed immediately
  by `set_state(status="working", text="<what you are doing>")`, before you start the work.
- Every request ends with `set_state(status="done", text="<one-line result>")`, or `status="error"` if
  you failed. Never leave `working` hanging.
- If you are blocked and need me: `set_state(status="needs_input", text="<what you need>")`, put the
  full question in your normal reply, then stop. I will open this session. Never wait or poll.
- `notify(text=...)` only for something worth my attention mid-task. Do not also notify for done,
  error or needs_input: they already show a bubble.
- Keep text to one plain line under 100 characters, with no secrets. On tasks longer than 30 minutes
  repeat `working` about every 15 minutes. If a call fails, carry on and do not retry in a loop.
- The `pingpal` skill has fuller guidance if needed.
```

### Why `working` first on every request

An AI session cannot tell in advance whether a request will take ten seconds or an hour, so a rule like
"report only the big ones" makes it stay silent at the start and report once at the end, or not at all.
"Always send `working` first, always finish with `done` or `error`" needs no judgement, and it is cheap:
two short calls per request.

### Deferred tools

With many MCP servers connected, some apps (the GitHub Copilot app, for one) do not give the model every
tool's full definition. They list tools by name only, and the model has to load the ones it wants with a
search tool (`tool_search_tool`, pattern `pingpal`) before it can call them. Models often skip that step, and
then PingPal is never called. The line about `tool_search_tool` in the snippet fixes this; it is harmless
where tools are not deferred. If your AI still forgets, say it stronger: "The pingpal tools are deferred: your
FIRST tool call must be `tool_search_tool` with pattern `pingpal`."

## Checking that it works

1. Start PingPal and open `http://127.0.0.1:7464/health` in a browser. It should answer `"ok": true`.
   `sessions` counts MCP sessions.
2. Send it a test message by hand, with no scripts or repo needed. A bubble should appear:

   ```powershell
   # Windows PowerShell
   Invoke-RestMethod http://127.0.0.1:7464/mcp -Method Post -ContentType "application/json" -Body '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"notify","arguments":{"source":"Test","text":"Hello from PowerShell"}}}'
   ```

   ```bash
   # macOS, Linux, Git Bash
   curl -s http://127.0.0.1:7464/mcp -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"notify","arguments":{"source":"Test","text":"Hello from curl"}}}'
   ```

3. Start a new AI session in a project where the skill or snippet is installed, and give it a task
   with a few steps. You should see a chip with the session's name appear, then a bubble when it finishes.

If step 2 works but step 3 shows nothing, the server is fine and the AI did not call the tools. Confirm
the `pingpal` MCP server is enabled in that session, and that the skill or instructions were loaded (a
new session, not an old one). If you cloned the repo, `./scripts/test-mcp.ps1` (or `.sh`) runs a fuller
check of every tool.

## Tuning

- **Too chatty:** add "Only use PingPal for requests that involve running commands or editing files" or
  "Do not use `notify`". Tell it to skip `working` and send only `done` if you want one bubble per request.
- **Too quiet** (a single `done` at the end, or nothing at all): check that the tools are loaded (see
  Deferred tools above) and that you used the snippet, not only the skill.
- **Different names per project:** tell the AI what to call itself, for example "Use `source`
  `Billing API` for every call in this repository."

The tool arguments and statuses are documented in the [README](https://github.com/tthung1997/pingpal#the-tools); the reasoning
behind them is in [DESIGN.md](https://github.com/tthung1997/pingpal/blob/main/docs/DESIGN.md).
