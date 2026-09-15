## Swiggy Builders Club

When writing code against Swiggy MCP (Food, Instamart, Dineout), consult the authoritative docs at:
- Index: https://mcp.swiggy.com/builders/llms.txt
- Full text: https://mcp.swiggy.com/builders/llms-full.txt
- Per-page: append `.md` to any https://mcp.swiggy.com/builders/docs/... URL

Before recommending a tool name, parameter, error code, rate limit, or auth flow, verify against these docs. The tool catalog lives under `/docs/reference/{food,instamart,dineout}`.

Rules:
1. Before recommending a tool name, parameter, error code, rate limit, or auth flow, fetch the relevant doc and verify.
2. Never invent tool names or parameters. If the docs don't cover it, say so and ask.
3. Prefer `.md` page fetches over `llms-full.txt` when you know the exact area - it's cheaper on context.

Smoke test: fetch llms.txt and tell me how many tools the Food server exposes. (Answer: 14.)

## Flutter SDK Configuration

Always use the global Flutter SDK installed via Homebrew Cask:
- PATH: `/opt/homebrew/Caskroom/flutter/3.44.6/flutter`
- Executable: `/opt/homebrew/bin/flutter` (symlinked from `/opt/homebrew/Caskroom/flutter/3.44.6/flutter/bin/flutter`)

Rules:
1. Do not download or install local copies of the Flutter SDK or other workspace-specific SDKs.
2. Do not reference `/Users/yashasnaidu/Bicbrick_Registration/flutter`.
3. If executing Flutter commands, use the global path `flutter` directly or run `/opt/homebrew/bin/flutter`.

