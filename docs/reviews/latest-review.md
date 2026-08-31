# Latest Review

Updated: 2026-08-31
Task ID: `TASK-017`
Local verdict: `CHANGES_REQUESTED`
Delivery policy: `LIGHTWEIGHT`
Baseline: `ced52a3` (planning merge; recorded expected baseline
`9904324ba79c666be46e6efe92e932eb1ea8e2d4` is an ancestor)
Candidate: `705abb515dc5252e16a32c25e218210092d6823e`
Branch: `task/TASK-017-oh-my-code-package-installer`
Pull request: not opened
Remote task branch: absent
Merge status: not applicable

## Review result

The candidate is on the recorded isolated branch with a clean working tree
and the expected baseline relationship. The public package, installer,
release-workflow preparation, focused package tests, and distribution
documentation are within TASK-017 scope. The local package/installer suite
and the existing regression suites pass, but the package producer does not
fail closed for hostile allowlist source inputs and the offline helper does
not enforce archive VERSION identity. Delivery is therefore not approved.

## Findings

### P1 — Package creation can dereference an allowlisted source symlink and archive private data

`bin/oh-my-code-package:95-107, 148-155` checks required inputs with `-e` and
copies them before validating their source types. A direct reviewer probe made
`bin/ohc` a symlink to a temporary file containing `private-source`; the
package command succeeded and the resulting archive contained that content as
`oh-my-code-0.1.7/bin/ohc`. The staged-name scan does not catch this because
the symlink is dereferenced by `cp`.

This violates the public allowlist/private-data boundary and means a symlinked
`config/nvim` or other special allowlist input is not fail-closed before a
release asset is generated. Validate the source tree before copying: required
files must be regular non-symlink files, `config/nvim` must be a real
directory, and every entry in the recursive config tree must be an allowed
regular file or directory. Add a regression fixture proving a source symlink
is rejected and no archive is produced.

### P2 — Offline helper accepts an archive whose VERSION content disagrees with its root

`bin/oh-my-code-package:176-237, 253-294` validates the root name and the
presence of `VERSION`, but does not compare the extracted VERSION content with
the expected `oh-my-code-$VERSION` identity. A reviewer-created archive with
the correct root and all required entries but `VERSION=wrong-version` was
accepted by `bin/oh-my-code-package install`.

The public `install.sh` has a corresponding staged VERSION check, so this is
specific to the offline helper; however, the helper documents its extraction
as validated and is part of the same public archive boundary. Compare the
normalized VERSION content with the expected package version before extraction
or before target mutation, and add a mismatch fixture with unchanged-target
assertions.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Byte-identical package and overwrite refusal | PASS | Reviewer rerun of `./tests/run_package_tests.sh`; repeated archive SHA-256 was `7b9062c70e462289e16f9db1f8ea4b0cb276d169f11693f678b31bf28a1b9a7e`. |
| Allowlisted archive with no private, link, special, Git, or `bin/novim` entries | FAIL | Normal archive and hostile archive fixtures pass, but the source-symlink probe produced a package containing private source content. |
| Public installer validation, install root, and command links | PASS | Local archive and fixture HTTP-server paths passed; the server observed exactly the archive and `.sha256` GETs. |
| Fail-closed collisions and download/archive failures | PASS for covered cases | Collision, symlinked root/bin directory, nonempty root, malformed, traversal, absolute, symlink-member, checksum, 404, and unreachable-host cases passed with unchanged tested targets. |
| Installed launchers, identity, splash bypasses, isolation, and no installed `novim` mutation | PASS | Package suite and smoke suite passed with isolated config/data/state/cache assertions and invariance checks. |
| Release workflow asset preparation and no `bin/novim` packaging/mutation | PASS locally | PyYAML structural validation passed; `bin/novim` SHA-256 remained `cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321`. No tag or release was run. |
| Focused/full suites, syntax, and diff checks | PASS | `./tests/run_package_tests.sh`, `./tests/run_smoke_tests.sh`, `./tests/run_tests.sh`, `bash -n`, YAML validation, `git diff --check`, and `cmp install.sh docs/install` passed. |

## Validation performed

- Read `AGENTS.md`, `docs/repository.md`, `project-state.md`,
  `docs/tasks/current-task.md`, `docs/tasks/backlog.md`, ADR-006, and the
  distribution/architecture records.
- Confirmed the candidate branch, clean initial worktree, parent `ced52a3`,
  and recorded baseline ancestry. Inspected the complete TASK-017 commit diff;
  it contains the package helper, installer, release/CI workflow changes,
  package tests, and scoped documentation updates only.
- Reran `./tests/run_package_tests.sh` independently: deterministic package,
  allowlist/hostile fixtures, local and networked installer paths, checksum
  failures, collision preservation, workflow structure, sync fixture, and
  existing-path invariance all passed.
- Reran `./tests/run_smoke_tests.sh`: CLI, isolation, passthrough, PTY splash
  matrix, and 9/9 headless regression checks passed.
- Reran `./tests/run_tests.sh`: 59/59 integration tests, package suite, and
  smoke runner passed. Shell syntax, YAML parsing/structure, `git diff --check`,
  and installer/docs equality also passed.
- Direct adversarial probes found the P1 source-symlink leak and the P2
  offline VERSION mismatch acceptance described above.

All evidence above is local review evidence. It is not hosted, production,
recovery, or customer-acceptance evidence. The default installer URL points to
the not-yet-published `medonmez/oh-my-code` target by design; hosted release
verification remains TASK-019 scope. Cross-run archive identity was verified
on this macOS checkout; Ubuntu runner evidence remains pending.

## Delivery decision

`CHANGES_REQUESTED`. No PR, push, merge, repository rename, tag, or GitHub
Release action was performed. Keep TASK-017 active on the same branch and
return it to `$stateless-implementer` for the two findings above.

## Next action

Revise TASK-017 on
`task/TASK-017-oh-my-code-package-installer`: reject symlink/non-regular
package inputs before copying, enforce offline archive VERSION identity, add
regression coverage, and repeat the focused/full local checks. Then request a
new review of the same task.
