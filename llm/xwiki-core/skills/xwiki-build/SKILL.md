---
name: xwiki-build
description: Build and test XWiki Maven modules. Use when building XWiki, running its tests, or when the user mentions mvn, a build, a failing test, or a specific XWiki module.
---

# Building and testing XWiki

XWiki is a multi-module Maven project. Almost every build needs the `legacy` profile.

## Full build (no integration tests, fast)

```bash
mvn clean install -Plegacy,integration-tests,snapshot \
  -Dxwiki.checkstyle.skip=true -Dxwiki.surefire.captureconsole.skip=true \
  -Dxwiki.revapi.skip=true -DskipITs
```

Drop `-DskipITs` to include integration tests. Add `-DskipTests` to skip all tests.

## Build a single module

```bash
mvn clean install -pl xwiki-platform-core/xwiki-platform-<module> -Plegacy,snapshot
```

## Run tests

```bash
# All unit tests in a module
mvn test -pl xwiki-platform-core/xwiki-platform-<module>

# A single test class
mvn test -pl xwiki-platform-core/xwiki-platform-<module> -Dtest=MyTestClass

# A single test method
mvn test -pl xwiki-platform-core/xwiki-platform-<module> -Dtest=MyTestClass#myMethod

# Integration tests
mvn verify -pl xwiki-platform-core/xwiki-platform-<module> -Pintegration-tests
```

## Notes

- The `legacy` profile activates backward-compatibility shim modules and is almost always required.
- The `snapshot` profile enables XWiki snapshot repositories.
- Skip flags worth knowing: `-Dxwiki.checkstyle.skip=true` (Checkstyle),
  `-Dxwiki.revapi.skip=true` (API compat), `-Dxwiki.surefire.captureconsole.skip=true`
  (stdout capture check).
