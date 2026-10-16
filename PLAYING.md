# PingPal

A tiny character at the bottom of your screen that shows what your AI agents are doing. PingPal runs a small
MCP server on your machine; your AI apps (Claude Code, GitHub Copilot, Codex, VS Code, ...) connect to it and
tell the character when they finish, fail or need you.

For Windows 10/11 (64-bit).

## Run it

1. Unzip the folder anywhere.
2. Double-click `PingPal.exe`.

There is no installer. The first time, Windows SmartScreen may say the app is "unrecognised", because it is not
code-signed. Choose **More info**, then **Run anyway**. The checksum is published with each release if you want
to verify the download.

The corgi appears at the bottom-right of your main screen and says *"Hi! Listening on port 7464"*. It stays on
top; clicks pass through everything except the character and its bubbles.

## Connect your AI

Point your AI app's MCP settings at this address (PingPal must be running):

    http://127.0.0.1:7464/mcp

For example, in Claude Code:

    claude mcp add --transport http --scope user pingpal http://127.0.0.1:7464/mcp

For GitHub Copilot, VS Code, Codex and others, and for the instructions that tell your AI when to report, see
the project page: https://github.com/tthung1997/pingpal (README, and `docs/AGENT_INSTRUCTIONS.md`).

PingPal listens on your own machine only (loopback), never on the network.

To make your AI actually use it, add the short snippet from `AGENT_INSTRUCTIONS.md` (in this zip) to your
AI's always-on instructions, and copy the `skills\pingpal` folder to your tool's skills folder
(`%USERPROFILE%\.copilot\skills\` for the GitHub Copilot app). Using both works best.

## Start with Windows

Copy `PingPal.exe` to a folder that won't change, for example `%LOCALAPPDATA%\Programs\PingPal\` (this zip's
folder name changes with each version). Press `Win+R`, run `shell:startup`, and put a shortcut to that exe in
the folder that opens. A Task Scheduler "At log on" task with a short delay also works; the project page has
the commands.

## Using it

- **Click the character** to open the history. That counts as checking your messages.
- **Click a bubble** to dismiss it.
- **Drag the character** to move it along the strip.
- **Right-click** for the menu: history, clear everything, switch character, next screen, quit.

## Your settings

Settings are saved in `%APPDATA%\PingPal\settings.cfg`. Extra character packs go in
`%APPDATA%\PingPal\packs\<name>\` (see `docs/PACKS.md` in the project). Delete the folder to reset.
