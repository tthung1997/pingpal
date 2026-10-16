# Teaching your AI to use PingPal

PingPal only helps if your AI sessions call it at the right moments, without spamming you. The server
already sends short usage instructions during the MCP handshake, but some clients do not show those
to the model, so add your own. There are two ways, and you can use both:

| | What it is | Use it when |
| --- | --- | --- |
| **The skill** (`skills/pingpal/SKILL.md`) | A complete guide the AI loads when it is relevant: what to call when, how to name itself, how to ask for you, what to avoid | Your tool supports skills. Best option: it is only loaded when needed |
| **The snippet** (below) | A short block for an always-on instructions file | Your tool has no skills, or you want a reminder in every session |

## Option A: the skill

A skill is a folder containing a `SKILL.md` (YAML frontmatter with `name` and `description`, then
Markdown). Copy the `pingpal` folder from this repo's `skills/` directory to where your tool looks for
skills:

```powershell
# Per user (all projects). This is where user skills live on a standard GitHub Copilot app install on Windows:
Copy-Item -Recurse skills\pingpal $HOME\.agents\skills\

# Per project (shared with your team, commit it):
#   GitHub Copilot  .github/skills/pingpal/SKILL.md
#   Claude Code     .claude/skills/pingpal/SKILL.md   (per user: ~/.claude/skills/pingpal/)
```

Folder names differ between tools and versions, so check your tool's documentation if the skill does
not show up. The file format is the same everywhere. Restart or start a new session afterwards:
skills are picked up when a session starts.

## Option B: the snippet

Paste this into `AGENTS.md` (Codex and others), `CLAUDE.md` (Claude Code),
`.github/copilot-instructions.md` (GitHub Copilot, per repository) or your tool's user-level
instructions file:

```markdown
## PingPal (desktop notifications)

Use the `pingpal` MCP server to keep me posted while you work. It has three tools: `notify`,
`set_state` and `clear`. Every call needs `source`: the title of this session if you know it,
otherwise a short description of the task (up to 80 characters), exactly the same on every call.

- When you finish real work (running commands, editing files, investigating), however short, call
  `set_state(status="done", text="<one-line result>")`, or `status="error"` if you failed. For a longer
  job (over about a minute) also send `set_state(status="working", text="<what you are doing>")` at the
  start, and always finish it with one of those.
- If you are blocked and need me: `set_state(status="needs_input", text="<what you need>")`, put the
  full question in your normal reply, then stop. I will open this session. Never wait or poll.
- `notify(text=...)` only for something worth my attention mid-task. Do not also notify for done,
  error or needs_input: they already show a bubble.
- Keep text to one plain line under 100 characters, with no secrets. Skip PingPal for plain chat
  answers where you did no work. On tasks longer than 30 minutes repeat `working` about every 15
  minutes. If a call fails, carry on and do not retry in a loop.
```

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

- **Too chatty:** add "Only use PingPal for tasks longer than five minutes" or "Do not use `notify`".
- **Too quiet:** add "Always send `working` at the start of any task".
- **Different names per project:** tell the AI what to call itself, for example "Use `source`
  `Billing API` for every call in this repository."

The tool arguments and statuses are documented in the [README](../README.md#the-tools); the reasoning
behind them is in [DESIGN.md](DESIGN.md).
