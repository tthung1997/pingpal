A tiny character that lives at the bottom of your screen and shows what your AI agents are up to. Your AI apps (Claude Code, GitHub Copilot, Codex, VS Code, ...) connect to PingPal's built-in MCP server and tell the character when they finish, fail or need you.

**Windows 10/11, 64-bit.** Unzip and run `PingPal.exe`. No installer. `README.txt` in the zip explains how to connect your AI.

- **SmartScreen:** the build isn't code-signed, so Windows may say the app is unrecognised. Choose **More info**, then **Run anyway**.
- **MCP address:** `http://127.0.0.1:7464/mcp` (this machine only). Setup for each AI app, and ready-made instructions for your AI, are in the [README](https://github.com/tthung1997/pingpal#connect-your-ai-apps) and [docs/AGENT_INSTRUCTIONS.md](https://github.com/tthung1997/pingpal/blob/main/docs/AGENT_INSTRUCTIONS.md).
- **Your settings** are in `%APPDATA%\PingPal\`. Delete the folder to reset.
- **Checksum:** the `.sha256` file is attached (SHA-256 of the zip).
- **Quit:** right-click the character, then Quit.

MIT licensed. Made with Godot 4.7.
