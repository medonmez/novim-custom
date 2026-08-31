# Latest Review

Updated: 2026-08-31
Task ID: `TASK-017`
Local verdict: `APPROVED`
Delivery policy: `LIGHTWEIGHT`
Baseline: `b501186` (prior review record; recorded expected baseline
`9904324ba79c666be46e6efe92e932eb1ea8e2d4` is an ancestor)
Candidate: `6b902a86bf3f6b5ffabf2e7d750d1cd962856312`
Branch: `task/TASK-017-oh-my-code-package-installer`
Pull request: not opened
Remote task branch: absent
Merge status: not attempted

## Review result

The candidate remains on the recorded isolated branch with a clean worktree
and the expected baseline relationship. The follow-up changes are limited to
the package helper, package/installer regression coverage, and the TASK-017
handoff. `install.sh`, `docs/install`, the release workflow, and the public
archive bytes remain unchanged from the reviewed candidate.

The two prior findings are resolved. Package creation now validates every
allowlisted source input before copying, rejecting symlinks and special files;
the offline helper now verifies archived VERSION identity before target
mutation. The new negative tests exercise both paths and preserve the clean
checkout afterward. No unresolved correctness, regression, security, privacy,
data-integrity, public-contract, or scope issue remains for local review.

## Findings

None blocking.

Non-blocking observations:

- The source-tree regression temporarily moves `bin/ohc` and creates a config
  symlink in the checked-out tree, restoring both on the passing path. The
  wrapper-guarded run ended clean; future test failures should retain the same
  cleanup guarantee so a failed probe cannot leave tracked source altered.
- Deterministic archive identity was independently confirmed on this macOS
  checkout. Ubuntu runner evidence remains pending; the release workflow is
  still preparation for TASK-019 and was not executed as a hosted release.
- Local `shellcheck` was unavailable in this environment. The repository CI
  shellcheck step remains the remote validation path; no required remote check
  was available or run during this local review.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Byte-identical package and overwrite refusal | PASS | Reviewer-guarded `./tests/run_package_tests.sh`; repeated archive SHA-256 remained `7b9062c70e462289e16f9db1f8ea4b0cb276d169f11693f678b31bf28a1b9a7e`. |
| Allowlisted archive with no private, link, special, Git, or `bin/novim` entries | PASS | Source-tree validation rejects symlinked required/config inputs before staging; normal manifest and hostile archive checks pass. |
| Public installer validation, install root, and command links | PASS | Local archive and fixture HTTP-server paths pass; exactly archive and `.sha256` assets are fetched. |
| Fail-closed collisions and download/archive failures | PASS | Collision, symlinked root/bin directory, nonempty root, malformed, traversal, absolute, symlink-member, allowlist, VERSION mismatch, checksum, 404, and unreachable-host cases preserve tested targets. |
| Installed launchers, identity, splash bypasses, isolation, and no installed `novim` mutation | PASS | Package/smoke suites pass; installed package identities, isolated paths, bypass controls, and no `bin/novim` alias are asserted. |
| Release workflow asset preparation and no `bin/novim` packaging/mutation | PASS locally | PyYAML structure checks pass; `bin/novim` remains SHA-256 `cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321`; no tag/release was run. |
| Focused/full suites, syntax, and diff checks | PASS | `./tests/run_package_tests.sh`, `./tests/run_smoke_tests.sh`, `./tests/run_tests.sh` (59/59), `bash -n`, YAML structure, `cmp install.sh docs/install`, and `git diff --check` pass. |

## Incident and recovery record

During the prior fixer investigation, a temporary probe wrote checkout
`bin/novim` bytes through the `~/.local/bin/novim` symlink onto the installed
`~/.local/share/novim/bin/novim` target. The resulting `novim 0.1.0` output was
incorrectly treated as unchanged because the post-mutation measurement used
the damaged file and provenance was inferred from README/LICENSE/VERSION
instead of the binary.

The installed target was subsequently restored only after the upstream
`link2004/novim` v0.1.7 release asset produced the recorded binary hash
`5955e1f2c223d13b024e263dca412f1acb96b69d4168b26b3fa3f7b14c1de26a`. This
review performed no write to the installed release. Read-only verification
now shows target mode `755`, the same `5955e1f2...` hash, and `novim 0.1.7`;
`bin/novim` remains `cb8e8785...`, and the normal Neovim config is absent.
The package, smoke, and full-suite runs were wrapped with the installed
binary hash/version before-and-after guard and preserved that state.

This is local incident and recovery evidence only; it is not hosted,
production, recovery-service, or customer-acceptance evidence. The review
does not treat the initial post-mutation invariance claim as valid evidence.

## Validation performed

- Read `AGENTS.md`, `docs/repository.md`, `project-state.md`,
  `docs/tasks/current-task.md`, `docs/tasks/backlog.md`, ADR-006, the prior
  review, and the distribution/architecture records.
- Confirmed candidate `6b902a8`, parent `b501186`, recorded baseline ancestry,
  correct task branch, and a clean worktree before review. Inspected the full
  follow-up diff and confirmed `install.sh`/`docs/install` byte identity.
- Reran `./tests/run_package_tests.sh` with installed `novim` hash/version and
  checkout-status guards; source symlink rejection, VERSION mismatch refusal,
  deterministic archive, installer failures, network fixture, workflow
  structure, and invariance checks passed.
- Reran `./tests/run_smoke_tests.sh` with the installed-release guard: CLI,
  isolation, passthrough, PTY splash matrix, and 9/9 headless checks passed.
- Reran `./tests/run_tests.sh` with the same installed-release guard: 59/59
  integration tests, package suite, and smoke runner passed.
- Ran `bash -n` on all changed shell scripts, PyYAML workflow structure checks,
  `git diff --check`, `python3 -m json.tool docs/project.json`, and the
  installed target mode/hash/version read-back.

## Delivery decision

`APPROVED` for LIGHTWEIGHT delivery. No hosted release, repository rename,
tag, or customer-acceptance claim is authorized by this task. The reviewed
branch may now be pushed for one traceability PR targeting `origin/main` and
merged promptly if no explicit repository/provider rule blocks it.

## Next action

Push `task/TASK-017-oh-my-code-package-installer`, open/update one PR for
TASK-017 against `main`, put this evidence and incident boundary in the PR,
merge when mergeable, verify the merged `origin/main`, then reconcile the
canonical task records before issuing TASK-018.
