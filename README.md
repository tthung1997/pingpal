# PingPal

A tiny character that lives in a corner of your screen and tells you what your AI agents are up to.

PingPal runs an **MCP server** on your machine. Point Claude Code, GitHub Copilot, Codex, VS Code or any
other MCP client at it, and the AI decides what the character says and does: *"Tests are green"*,
*"Need your call on the migration"*, a happy dance when a long task finishes. You stop babysitting
five terminals and just glance at the character.

- Transparent, always-on-top, **click-through** except on the character and its bubbles.
- Several AIs at once: each gets its own color, accessory and tray chip; urgent things jump the queue, floods are batched ("4 agents finished").
- When nobody is talking, it does its own thing: wanders, naps, plays.
- Characters are swappable **packs** (sprite sheet + JSON). Ships with one placeholder, *Pip*.

Built with Godot 4.7 (GDScript, no addons). See [docs/DESIGN.md](docs/DESIGN.md) for how it works.

## Run it

You need [Godot 4.7](https://godotengine.org/download) (standard build, not .NET).

```powershell
git clone <this repo> pingpal
cd pingpal
godot --path .            # or open project.godot in the editor and press F5
```

The first launch imports assets, then Pip appears at the bottom-right of your main screen and says
*"Hi! Listening on port 7464"*. The MCP endpoint is:

```
http://127.0.0.1:7464/mcp
```

It listens on loopback only. Check it from a terminal:

```powershell
./scripts/test-mcp.ps1          # Windows / PowerShell 7 or 5.1
./scripts/test-mcp.sh           # macOS / Linux / Git Bash (curl)
```

### Controls

| Action | Result |
| --- | --- |
| Left-click the character | Open/close the history (everything you missed, plus any open question). Re-opens a question whose bubble timed out. |
| Click a bubble | Dismiss it |
| Drag the character | Move it along the strip; it wanders again after you let go |
| Right-click | Menu: history, clear everything, switch strip/corner mode, next screen, quit |
| Click a tray chip | Open the history |

### Options

Command-line flags (after `--` when launching through Godot) override `user://settings.cfg`
(`%APPDATA%\PingPal\settings.cfg` on Windows). Flags are never saved.

```
godot --path . -- --port=9000 --mode=corner --scale=4 --pack=pip --token=secret
```

| Flag | Meaning | Default |
| --- | --- | --- |
| `--port=N` | MCP port (`0` picks a free one; it is printed at startup) | `7464` |
| `--mode=strip\|corner\|window` | Full-width strip along the bottom, small corner window, or a normal window (handy for debugging) | `strip` |
| `--pack=ID` | Character pack id | `pip` |
| `--scale=N` | Character magnification (1-8) | `3` |
| `--token=SECRET` | Require `Authorization: Bearer SECRET` from clients | off |
| `--no-always-on-top`, `--no-click-through` | Opt out of overlay behaviour | |
| `--screenshot=PATH` `[--screenshot-delay=S] [--screenshot-history]` | Dev: save the rendered overlay (with alpha) and quit | |

Persisted settings (`[pingpal]` section of `settings.cfg`): `port`, `mode`, `pack_id`, `pixel_scale`,
`always_on_top`, `click_through`, `fps_cap`, `auth_token`.

## Connect your AI apps

Every client just needs the URL. Start PingPal first. Replace the port if you changed it, and add a
bearer-token header if you set `--token`.

### Claude Code

```bash
claude mcp add --transport http --scope user pingpal http://127.0.0.1:7464/mcp
```

or in `.mcp.json` / `~/.claude.json`:

```json
{
  "mcpServers": {
    "pingpal": { "type": "http", "url": "http://127.0.0.1:7464/mcp" }
  }
}
```

### VS Code (GitHub Copilot Chat agent mode)

`.vscode/mcp.json` in a workspace, or *MCP: Open User Configuration* for all workspaces:

```json
{
  "servers": {
    "pingpal": { "type": "http", "url": "http://127.0.0.1:7464/mcp" }
  }
}
```

### GitHub Copilot (CLI and the Copilot app)

`~/.copilot/mcp-config.json` (or `/mcp add` in the CLI):

```json
{
  "mcpServers": {
    "pingpal": { "type": "http", "url": "http://127.0.0.1:7464/mcp", "tools": ["*"] }
  }
}
```

### Codex

`~/.codex/config.toml`:

```toml
[mcp_servers.pingpal]
url = "http://127.0.0.1:7464/mcp"
```

or `codex mcp add pingpal --url http://127.0.0.1:7464/mcp`. (Older Codex builds need
`experimental_use_rmcp_client = true` for HTTP servers.)

### Clients that only speak stdio (e.g. Claude Desktop)

Bridge with [`mcp-remote`](https://www.npmjs.com/package/mcp-remote):

```json
{
  "mcpServers": {
    "pingpal": { "command": "npx", "args": ["-y", "mcp-remote", "http://127.0.0.1:7464/mcp"] }
  }
}
```

### Tell the AI how to use it

PingPal sends usage instructions during the MCP handshake, but a line in your agent instructions
(`CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`) makes it reliable:

> Use the `pingpal` MCP server to keep me posted: `set_state(status="working")` when you start a
> long task and `set_state(status="done")` when it finishes; `notify` for a short one-liner when
> something is worth my attention; `ask` only when you are genuinely blocked on a decision. Keep
> text under ~100 characters and pass `source` as "<your app> · <project>".

## The tools

| Tool | Arguments | What it does |
| --- | --- | --- |
| `notify` | `text`, `source?`, `mood?` neutral/happy/excited/alert/thinking/sad/sleepy/error, `priority?` low/normal/high/urgent | Speech bubble + reaction. Low priority is batched; urgent interrupts. |
| `set_state` | `status` working/done/needs_input/error/idle, `source?`, `text?` | Updates the tray chip. `done`, `needs_input` and `error` also announce themselves. |
| `perform` | `action` wave/jump/dance/spin/cheer/play/think/alert/sad/sleep/wake/wander/idle, `source?`, `seconds?` | A physical action with no text. |
| `ask` | `question`, `choices?` (2-4, default Yes/No), `source?`, `timeout_seconds?` (default 45) | Shows buttons and **waits** for a click. Returns `{answered, choice, index}` or `{answered:false, reason}`. |
| `clear` | `source?`, `all?` | Removes your queued messages, bubble, questions and status (or everyone's with `all`). |

`source` names the caller ("Claude Code", "Copilot", ...). It defaults to the MCP client's name from
the handshake, so it is optional, but add a suffix ("Claude Code · api") to tell parallel agents from
the same app apart.

By hand:

```powershell
$h = @{ "Content-Type" = "application/json" }
Invoke-RestMethod http://127.0.0.1:7464/mcp -Method Post -Headers $h -Body '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"notify","arguments":{"source":"Me","text":"Hello!","mood":"happy"}}}'
```

```bash
curl -s http://127.0.0.1:7464/mcp -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"notify","arguments":{"source":"Me","text":"Hello!","mood":"happy"}}}'
```

## Characters

A pack is a folder with `pack.json` and a sprite sheet: `packs/<id>/` in the project, or
`user://packs/<id>/` (`%APPDATA%\PingPal\packs\<id>`) to add one without touching the repo. See
[docs/DESIGN.md](docs/DESIGN.md#character-packs) for the manifest. `packs/pip/` is a complete
example; regenerate its placeholder art with:

```powershell
godot --headless --path . --script res://tools/make_placeholder_pack.gd
```

A `"kind": "pet"` pack wanders, naps and plays; `"kind": "avatar"` stays put and only emotes.

## Tests

```powershell
./scripts/run-tests.ps1 -Godot path\to\godot_console.exe     # or set $env:GODOT
# equivalent: godot --headless --path . --import ; godot --headless --path . --script res://tests/run_tests.gd
```

Covers pack loading, the idle state machine, the notification manager (priority, batching, asks,
status), the MCP protocol, the HTTP server over real loopback sockets, and the main scene driven with
synthetic clicks. `scripts/test-mcp.*` check a *running* app from outside.

## Troubleshooting

- **"Can't listen on port 7464"**: another PingPal (or program) has it. Use `--port=`.
- **Character hidden behind a full-screen game**: exclusive full-screen apps cover overlays. Use windowed/borderless mode, or `--mode=window` to debug.
- **A client says the session is invalid after restarting PingPal**: PingPal accepts unknown session ids, so just retry; reconnecting restores the client name, otherwise pass `source`.
- **Nothing is clickable / everything is click-through**: run with `--no-click-through` to rule out the passthrough region.
- Windows only draws pixels inside the click region (a Godot/OS quirk), so everything interactive is included in it by design.

## Security

The server binds `127.0.0.1` only, rejects requests whose `Host`/`Origin` are not local (DNS-rebinding
protection), caps request and header sizes, and can require a bearer token. Any local process can still
talk to it unless you set `--token`; messages are text shown on screen, nothing is executed.
