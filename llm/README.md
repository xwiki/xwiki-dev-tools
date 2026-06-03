# LLM tooling (Claude Code marketplace)

This subproject distributes shared LLM configuration for XWiki org repositories as a
[Claude Code plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces).
The marketplace manifest lives at the repository root (`/.claude-plugin/marketplace.json`); the
plugins themselves live here under `llm/`.

## Plugins

| Plugin       | Scope                                                                       |
|--------------|-----------------------------------------------------------------------------|
| `xwiki-core` | Org-wide conventions, MCP servers and dev skills for all xwiki org repos     |

### `xwiki-core` contents

- **Org conventions** (`instructions/xwiki-org.md`) — injected into every session via a
  `SessionStart` hook, **scoped by git remote** so it only applies inside `xwiki/*` and
  `xwiki-contrib/*` repos (never in personal projects). This is the shared "CLAUDE.md equivalent".
- **MCP servers** (`.mcp.json`) — `discourse` (forum.xwiki.org) and `sonarqube` (SonarCloud).
  `SONARQUBE_TOKEN` and `SONARQUBE_PROJECT_KEY` are read from the environment; no secrets are
  committed. The project key is repo-specific — set it per repo (or override in a repo-level
  `.mcp.json`).
- **Skills** (`skills/`) — e.g. `xwiki-build` (canonical Maven build/test commands).

The hook is written in Node (`.mjs`), which ships with Claude Code, so it runs on Windows, macOS
and Linux without a bash or `jq` dependency.

## Install

```
/plugin marketplace add https://github.com/xwiki/xwiki-dev-tools
/plugin install xwiki-core@xwiki-dev-tools
```

For local development against a checkout:

```
/plugin marketplace add /path/to/xwiki-dev-tools
/plugin install xwiki-core@xwiki-dev-tools
```

## Validate

```
claude plugin validate ./llm/xwiki-core
```
