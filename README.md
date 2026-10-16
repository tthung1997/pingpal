# PingPal

A tiny character that lives in a corner of your screen and tells you what your AI agents are up to.

PingPal runs an **MCP server** on your machine. Point Claude Code, GitHub Copilot, Codex, VS Code or any
other MCP client at it, and the AI decides what the character says and does: *"Tests are green"*,
*"Need your input: which branch?"*, the character perking up when a long task finishes. You stop babysitting
five terminals and just glance at the character.

- Transparent, always-on-top, **click-through** except on the character and its bubbles.
- Several AIs at once: each gets its own color and tray chip; urgent things jump the queue, floods are batched ("4 agents finished").
- When nobody is talking, it loops an idle animation and now and then takes a short random break (nap, stretch, ...). A new message gets one neutral attention animation, which keeps going until you check it (click the bubble or the character).
- Characters are swappable **packs** (sprite sheet + JSON). Ships with a pixel-art corgi (default) and a placeholder blob, *Pip*.

Built with Godot 4.7 (GDScript, no addons). See [docs/DESIGN.md](docs/DESIGN.md) for how it works.

## Run it

You need [Godot 4.7](https://godotengine.org/download) (standard build, not .NET).

```powershell
git clone <this repo> pingpal
cd pingpal
godot --path .            # or open project.godot in the editor and press F5
```

The first launch imports assets, then the corgi appears at the bottom-right of your main screen and says
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
| Left-click the character | Open/close the history (everything you missed). Opening it counts as checking your messages: it ends the attention animation and clears finished, failed and waiting-for-you chips. |
| Click a bubble | Dismiss it; that counts as reading it |
| Drag the character | Move it along the strip; it resumes idling (or its attention animation, if something is still unread) after you let go |
| `Right-click` | Menu: history, clear everything (messages, status chips and the history; it asks "are you sure?" first), switch character pack (remembered across runs), next screen, quit |
| Click a tray chip | Open the history |

### Options

Command-line flags (after `--` when launching through Godot) override `user://settings.cfg`
(`%APPDATA%\PingPal\settings.cfg` on Windows). Flags are never saved.

```
godot --path . -- --port=9000 --scale=4 --pack=pip --token=secret
```

| Flag | Meaning | Default |
| --- | --- | --- |
| `--port=N` | MCP port (`0` picks a free one; it is printed at startup) | `7464` |
| `--pack=ID` | Character pack id | `corgi` |
| `--scale=N` | Character magnification (1-8) | `2` |
| `--token=SECRET` | Require `Authorization: Bearer SECRET` from clients | off |
| `--no-always-on-top`, `--no-click-through` | Opt out of overlay behaviour | |
| `--screenshot=PATH` `[--screenshot-delay=S] [--screenshot-history]` | Dev: save the rendered overlay (with alpha) and quit | |

Persisted settings (`[pingpal]` section of `settings.cfg`): `port`, `pack_id`, `pixel_scale`,
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
> something is worth my attention; `set_state(status="needs_input", text="<what you need>")` when you
> are blocked on me, then stop and wait (I will open your session). Keep text under ~100 characters
> and always pass `source` as the title of this session (or a short description of its task), the
> same on every call.

## The tools

| Tool | Arguments | What it does |
| --- | --- | --- |
| `notify` | `source`, `text`, `priority?` low/normal/high/urgent | Speech bubble + attention animation. Low priority is batched; urgent interrupts. |
| `set_state` | `source`, `status` working/done/needs_input/error/idle, `text?` | Updates the tray chip. `done`, `needs_input` and `error` also announce themselves with `text`. `done` and `error` chips also stay until you open the history. `needs_input` is how a session says "come to my session": its chip stays until you open the history too. |
| `clear` | `source` | Removes your own queued messages, bubble and status. Other sources and the history are never affected: only the user's "Clear everything" menu item clears everything. |

There is deliberately no tool for asking questions with buttons: a real question usually needs the
session's context, so the AI flags `needs_input` and you answer in the session itself.

`source` is **required on every call**. It is a name that identifies the calling session, up to 80
characters: the session's title if the model knows it ("Add contributor guide for character packs"),
otherwise a short description of its task or repo. Each distinct name, compared case-insensitively, is
its own source with its own color, tray chip and status, so a session picks its look by choosing its
name. Use the same name on every call: a call with a different name counts as a different source. A
call without `source`, or with one over 80 characters, is rejected as an error. Long names are cut
with an ellipsis in the speech bubble and wrap in the history, where they show in full.

By hand:

```powershell
$h = @{ "Content-Type" = "application/json" }
Invoke-RestMethod http://127.0.0.1:7464/mcp -Method Post -Headers $h -Body '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"notify","arguments":{"source":"Me","text":"Hello!"}}}'
```

```bash
curl -s http://127.0.0.1:7464/mcp -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"notify","arguments":{"source":"Me","text":"Hello!"}}}'
```

## Characters

A pack is a folder with `pack.json` and a sprite sheet: `packs/<id>/` in the project, or
`user://packs/<id>/` (`%APPDATA%\PingPal\packs\<id>`) to add one without touching the repo. See
[docs/PACKS.md](docs/PACKS.md) for how to make and contribute one, and
[docs/DESIGN.md](docs/DESIGN.md#4-character-packs) for the manifest.

| Pack | What | Art source |
| --- | --- | --- |
| `corgi` (default) | A ginger corgi: sits and idles, with nap / happy / sad breaks; its thinking pose gets your attention | `art/corgi/`, built by `tools/art/prep_sheet.py` + LibreSprite |
| `corgi_desk` | A coder corgi in a hoodie, headphones and glasses working at a desk: types away while idle, chews a bone or naps in a sleep mask on breaks, and raises a paw for attention | `tools/art/corgi_desk.js`, built by LibreSprite (`python tools/art/build.py corgi_desk`) |
| `pip` | Placeholder blue blob with nap / play / dance breaks | `tools/make_placeholder_pack.gd` |

The corgi is the reference art itself, not a redraw. It came from ten generated 4-panel strips
(one per animation, same character on a dark floor). `tools/art/prep_sheet.py` cuts the dog out of
each panel (fur colours plus its dark outline, with the Zzz, "?" and tears), re-pixelates it onto a
real 1/8-scale pixel grid, aligns every animation to one ground line and body centre, and quantizes
the whole sheet to one 32-colour palette: `art/corgi/base_sheet.png` + `layout.json` (committed).
`tools/art/corgi.js` then runs headless in [LibreSprite](https://libresprite.github.io/) to add the
few symbols the references lack (hearts, music notes, "!") and writes `packs/corgi/sheet.png`.
Needs `python` + Pillow + numpy; set `LIBRESPRITE_EXE` if LibreSprite is not on `PATH`.

```powershell
python tools/art/build.py corgi                           # base sheet -> packs/corgi/sheet.png
python tools/art/preview.py packs/corgi/sheet.png out.png # enlarged preview
# re-make the base sheet from reference strips (idle, walk, sleep, thinking, happy, alert, sad):
python tools/art/prep_sheet.py path/to/refs art/corgi/base_sheet.png --layout art/corgi/layout.json
```

The reference images themselves are not in the repo. Re-running reproduces identical pixels.

**Making a character.** Every pack uses the same small, species-neutral chain, so a pet, a person or
a robot all work: one looping `idle` animation (required), one neutral `attention` animation
(required; played for every new message) and any number of short `breaks` (a nap, a stretch, ...)
played at random while idle. 2-4 frames each. The step-by-step guide, art rules, LibreSprite build
workflow and PR checklist are in [docs/PACKS.md](docs/PACKS.md). The corgi sheet still contains
`walk` and `alert` rows that no pack uses. The clickable area follows
the visible pixels of the current frame, so transparent parts of a large frame never block clicks.

## Tests

```powershell
./scripts/run-tests.ps1 -Godot path\to\godot_console.exe     # or set $env:GODOT
# equivalent: godot --headless --path . --import ; godot --headless --path . --script res://tests/run_tests.gd
```

Covers pack loading, the idle state machine, the notification manager (priority, batching, read state,
status), the MCP protocol, the HTTP server over real loopback sockets, and the main scene driven with
synthetic clicks. `scripts/test-mcp.*` check a *running* app from outside.

## Troubleshooting

- **"Can't listen on port 7464"**: another PingPal (or program) has it. Use `--port=`.
- **Character hidden behind a full-screen game**: exclusive full-screen apps cover overlays. Use windowed/borderless mode in the game.
- **A client says the session is invalid after restarting PingPal**: PingPal accepts unknown session ids, so just retry. Every tool call carries its own `source`, so nothing is lost.
- **Nothing is clickable / everything is click-through**: run with `--no-click-through` to rule out the passthrough region.
- Windows only draws pixels inside the click region (a Godot/OS quirk), so everything interactive is included in it by design.

## Security

The server binds `127.0.0.1` only, rejects requests whose `Host`/`Origin` are not local (DNS-rebinding
protection), caps request and header sizes, and can require a bearer token. Any local process can still
talk to it unless you set `--token`; messages are text shown on screen, nothing is executed.
