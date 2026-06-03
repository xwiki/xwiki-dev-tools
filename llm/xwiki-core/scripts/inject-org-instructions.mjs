#!/usr/bin/env node
// SessionStart hook for the xwiki-core plugin.
// Injects org-wide XWiki conventions as additionalContext, but ONLY when the current repo
// belongs to the `xwiki` or `xwiki-contrib` GitHub org. Personal repos get nothing.
// Written in Node (which Claude Code requires) so it works on Windows, macOS and Linux.

import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const pluginRoot = process.env.CLAUDE_PLUGIN_ROOT;

// Resolve the repo's origin remote. If this isn't a git repo, inject nothing.
let remote = "";
try {
  remote = execFileSync("git", ["-C", projectDir, "remote", "get-url", "origin"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"]
  }).trim();
} catch {
  process.exit(0);
}

// Scope: only xwiki/* and xwiki-contrib/* repos (handles both SSH and HTTPS remotes).
if (!/github\.com[:/](xwiki|xwiki-contrib)\//.test(remote)) {
  process.exit(0);
}

let text;
try {
  text = readFileSync(`${pluginRoot}/instructions/xwiki-org.md`, "utf8");
} catch {
  process.exit(0);
}

process.stdout.write(
  JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: text
    }
  })
);
