# Repository Documentation Contract

Repository: `novim-custom` (public target: `oh-my-code`)
Updated: 2026-08-29

This file is the routing manifest for product documentation and the agent
workflow. Read it before creating or relocating project records.

## Canonical documentation paths

- Product decisions: `docs/product/`
- Architecture overview: `docs/architecture.md`
- Detailed architecture and contracts: `docs/architecture/`
- Architecture decision records: `docs/adr/`
- Task backlog and current task: `docs/tasks/`
- Reviews: `docs/reviews/`
- Local distribution and synchronization runbooks: `docs/LOCAL_DISTRIBUTION.md`
  and `docs/UPSTREAM_SYNC.md`
- Current project state: `project-state.md`
- Machine-readable project manifest: `docs/project.json`
- Repository-local agent rules: `AGENTS.md`

The upstream project already has a public documentation site under `docs/`.
`docs/index.html`, `docs/HOW_IT_WORKS.md`, and its visual assets remain
upstream-facing product/site documentation. Workflow records use the
subdirectories listed above; no parallel copy of those existing documents is
created.

## Workflow policy

- Default delivery policy: `LIGHTWEIGHT`
- Implement one task at a time on its recorded isolated branch.
- Use `$stateless-implementer` for implementation and
  `$project-orchestrator` for planning, review, delivery, and task advancement.
- Use `STRICT` only for explicit production, hosted, security, privacy, data
  migration, recovery, branch-protection, or mandatory-check requirements.
- Keep local, hosted, production, recovery, and customer-acceptance evidence
  distinct.

## Repository-specific notes

- Purpose: Maintain oh-my-code, a terminal-first code workbench for developers
  who want a VS Code-like workflow inside the terminal.
- Source baseline: `https://github.com/link2004/novim`, currently cloned at
  tag `v0.1.7`, commit `8e36d447ee9c73d29b75f3dfc50db9452a2addf1`.
- Local checkout assumption: `/Users/mert/novim-custom`.
- Runtime and commands: upstream `bin/novim` remains a preserved reference;
  public work launches through `ohc`, with `novim-dev` retained as a
  one-release compatibility alias.
- Remote delivery: current `origin` is the personal repository
  `https://github.com/medonmez/novim-custom.git`; the accepted public target is
  `https://github.com/medonmez/oh-my-code` and the rename is pending the
  release-delivery task. `upstream` remains the official source repository.
  Use a task branch and pull request for subsequent remote delivery.
- Deployment or release notes: the first public release is planned as
  `v1.0.0`; no hosted release exists yet.
- Sensitive-data boundaries: source and Git metadata are local. Do not put
  credentials, tokens, private source, or raw user data into repository docs.
  The development command must not perform network actions by default.
- Packaging boundary: `bin/oh-my-code-package` builds the public
  deterministic `oh-my-code-<VERSION>.tar.gz` archive, and `install.sh`
  (synced to `docs/install`) is the networked installer for the declared
  public Release asset. Neither packages `bin/novim`, writes the installed
  `novim` paths, or performs upstream synchronization. Hosted release
  publication remains TASK-019 scope.
