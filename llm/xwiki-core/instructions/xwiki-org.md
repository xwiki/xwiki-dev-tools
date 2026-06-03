# XWiki org-wide conventions

These conventions apply to every repository in the `xwiki` and `xwiki-contrib` GitHub
organizations. They are injected automatically at the start of each session by the `xwiki-core`
plugin. Repo-specific `CLAUDE.md` files add to (and may override) what follows.

## Project facts

- **Issue tracker:** https://jira.xwiki.org (NOT GitHub Issues). Reference issues by their JIRA key
  (e.g. `XWIKI-12345`).
- **Dev guide:** https://dev.xwiki.org/xwiki/bin/view/Community/
- **CI:** https://ci.xwiki.org — build scans on Develocity at https://ge.xwiki.org/scans
- XWiki Commons, XWiki Rendering and XWiki Platform share the **same version** at any given time.

## Commit messages

- Prefix the summary with the JIRA issue key when there is one: `XWIKI-12345: <summary>`.
- Use `[Misc]` as the prefix for changes that have no associated issue.

## Build (Maven)

- Almost always enable the `legacy` profile. Common snapshot build:
  `mvn clean install -Plegacy,integration-tests,snapshot`
- Skip slow checks while iterating:
  `-Dxwiki.checkstyle.skip=true -Dxwiki.surefire.captureconsole.skip=true -Dxwiki.revapi.skip=true`
- Use `-DskipITs` to skip integration tests, `-DskipTests` to skip all tests.

## Code conventions

- Avoid adding new code to `xwiki-platform-oldcore` (`com.xpn.xwiki.*`); prefer a feature module.
- Use the XWiki Component system (`@Component`, `@Inject`, `@Role`) rather than `XWikiContext`
  in new code.
- `-legacy` modules only re-export deprecated APIs — never add new logic there.
