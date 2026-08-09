# Commit Conventions & Versioning

## Conventional Commits

All commits on `main` **must** follow the [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) specification.

### Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Allowed Types

| Type | Purpose | Triggers Release? |
|------|---------|-------------------|
| `feat` | New feature or capability | ✅ minor bump |
| `fix` | Bug fix | ✅ patch bump |
| `docs` | Documentation only | ❌ |
| `style` | Formatting, whitespace | ❌ |
| `refactor` | Code change (no new feature, no fix) | ❌ |
| `perf` | Performance improvement | ✅ patch bump |
| `test` | Adding or correcting tests | ❌ |
| `build` | Build system or external dependencies | ❌ |
| `ci` | CI configuration and scripts | ❌ |
| `chore` | Maintenance tasks | ❌ |

### Breaking Changes

Append `!` after the type or include a `BREAKING CHANGE:` footer to trigger a **major** version bump:

```
feat!: replace proxy_port variable with port_config object

BREAKING CHANGE: proxy_port variable removed; use port_config.listen instead.
```

### Examples

```
feat: add IMDSv2 enforcement via metadata_options
fix: correct security group egress rule for IPv6
docs: add architecture diagram to README
ci: add tflint step to release workflow
chore: update .gitignore to exclude .terraform.lock.hcl
```

---

## Semantic Versioning Strategy

This project uses [semantic-release](https://github.com/semantic-release/semantic-release) to automate version management and GitHub releases.

### How It Works

1. Push (or merge) to `main` triggers the release workflow.
2. `semantic-release` analyzes commits since the last tag.
3. If release-worthy commits exist (`feat:`, `fix:`, `perf:`, or `BREAKING CHANGE`), a new GitHub release is created with:
   - Incremented semver tag (e.g., `v1.2.0`)
   - Auto-generated changelog from commit messages

### Version Bumps

| Commit Type | Version Bump | Example |
|-------------|-------------|---------|
| `fix:`, `perf:` | Patch (0.0.X) | v1.0.0 → v1.0.1 |
| `feat:` | Minor (0.X.0) | v1.0.0 → v1.1.0 |
| `BREAKING CHANGE` / `!` | Major (X.0.0) | v1.0.0 → v2.0.0 |

### Consuming the Module

Users pin to a semver tag:

```hcl
module "proxy" {
  source = "github.com/ql4b/terraform-aws-ec2-proxy?ref=v1.0.0"
}
```

### Maintenance Branches

For backporting fixes to older major versions, create a branch named `N.x` (e.g., `1.x`). Pushes to maintenance branches also trigger releases scoped to that version line.

### Configuration

- `.releaserc.yml` — semantic-release configuration
- `.github/workflows/release.yml` — GitHub Actions workflow

### No Manual Tags

Do **not** create tags manually. All tagging is handled by `semantic-release` to maintain a consistent, auditable release history.

---

## Definition of Done

Before committing a `feat:` or `fix:` that changes module behavior:

- [ ] `CURRENT_STATE.md` reflects the new capability, removed limitation, or state change
- [ ] `ENHANCEMENTS.md` item checked off (if the work completes a backlog item)
- [ ] `terraform fmt` passes
- [ ] `terraform validate` passes

For `docs:`, `ci:`, `chore:`, and `refactor:` commits, update steering files only if the project's state or structure meaningfully changed (e.g., new CI pipeline, new file layout).
