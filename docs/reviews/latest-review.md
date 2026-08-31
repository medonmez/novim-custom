# Latest Review

Updated: 2026-08-31
Task ID: `TASK-017`
Local verdict: `CHANGES_REQUESTED`
Delivery policy: `LIGHTWEIGHT`
Implementation baseline: `b501186` (recorded expected baseline
`9904324ba79c666be46e6efe92e932eb1ea8e2d4` is an ancestor)
Reviewed head: `ad0ace2a98a3e0bf528504b774ae0325f8fff78c`
Implementation candidate: `6b902a86bf3f6b5ffabf2e7d750d1cd962856312`
Task branch: `task/TASK-017-oh-my-code-package-installer`
Pull request: `https://github.com/medonmez/novim-custom/pull/31` (`MERGED`)
Merge commit: `f070a7446f6fe93d2e1ba32e15d2e0fe45f27ff8`
Target branch contains reviewed head: `YES`

## Review result

The corrected implementation passed local review and the two prior package
findings are resolved. The branch was pushed and PR #31 was opened as the
single traceability PR. Because `main` has no branch protection, GitHub
allowed the merge while the only CI check was still queued. After merge, the
repository `shellcheck` job failed on the unchanged public installer line
`install.sh:171` (the same source is `docs/install:171`) with `SC1003`.

This is a real repository validation failure, so the task is not accepted
despite the merge. The same TASK-017 needs a follow-up correction and review;
no successor task is issued.

## Findings

### P1 — Public installer fails the repository ShellCheck job

The CI run [33367609435](https://github.com/medonmez/novim-custom/actions/runs/33367609435)
failed in `Run ShellCheck` at `install.sh:171`:

```text
SC1003 (info): Want to escape a single quote?
```

The offending backslash-regex literal is duplicated byte-for-byte in
`docs/install:171`. Correct both installer copies while preserving rejection
of archive entries containing backslashes, then rerun ShellCheck and the
focused/full local checks. Do not silence the check broadly without retaining
the validation behavior.

## Resolved prior findings

- The P1 source-symlink leak is resolved by `validate_source_tree` in
  `bin/oh-my-code-package:95-127`, before copying or archive creation. New
  tests reject symlinked required/config inputs and leave no output/staging
  bytes.
- The P2 offline VERSION identity gap is resolved by
  `bin/oh-my-code-package:298-307`, which stages and compares VERSION before
  touching the target. The wrong-version fixture is rejected by both helper
  and public installer paths.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Byte-identical package and overwrite refusal | PASS | Guarded `./tests/run_package_tests.sh`; archive SHA-256 remained `7b9062c70e462289e16f9db1f8ea4b0cb276d169f11693f678b31bf28a1b9a7e`. |
| Allowlisted archive and source fail-closed boundary | PASS locally | Source symlink/non-regular validation and hostile archive tests pass before staging/output. |
| Public installer validation, root, and links | PASS locally | Local and fixture-server installs pass; exactly archive and checksum assets are fetched. |
| Collision and malformed/download failure safety | PASS locally | Collision, symlink, nonempty, hostile, VERSION mismatch, checksum, 404, and unreachable-host cases preserve tested targets. |
| Installed launchers, identity, isolation, and installed `novim` boundary | PASS locally | Package/smoke tests pass; installed-release hash/version guards remain unchanged. |
| Release workflow assets and `bin/novim` boundary | PASS locally | YAML structure passes; `bin/novim` remains SHA-256 `cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321`; no tag/release was run. |
| Required validation including ShellCheck | FAIL | Local `bash -n`, YAML, package/smoke/full suites, `cmp`, and diff checks pass, but remote CI ShellCheck fails with `SC1003`. |

## Incident and recovery record

During the fixer investigation, a temporary probe wrote checkout `bin/novim`
bytes through the `~/.local/bin/novim` symlink onto the installed
`~/.local/share/novim/bin/novim` target. The resulting `novim 0.1.0` output
was incorrectly treated as unchanged because the post-mutation measurement
used the damaged file and provenance was inferred from README/LICENSE/VERSION
instead of the binary.

The target was restored only after the upstream `link2004/novim` v0.1.7
release asset matched the recorded binary hash
`5955e1f2c223d13b024e263dca412f1acb96b69d4168b26b3fa3f7b14c1de26a`.
This review performed no write to the installed release. Read-only checks
show mode 755, that hash, and `novim 0.1.7`; `bin/novim` remains
`cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321`, and the
normal Neovim config is absent. The validation runs were guarded by installed
binary hash/version before-and-after checks and preserved that state.

The handoff’s previous claim that the restored binary still reported
`novim 0.1.0` was corrected in the canonical task record. This incident and
recovery evidence is local only; it is not hosted, production,
recovery-service, or customer-acceptance evidence.

## Validation performed

- Read `AGENTS.md`, `docs/repository.md`, `project-state.md`,
  `docs/tasks/current-task.md`, `docs/tasks/backlog.md`, ADR-006, and the
  previous review.
- Confirmed the candidate branch, clean worktree, parent `b501186`, and
  baseline ancestry. Inspected the full follow-up diff and confirmed
  `install.sh`/`docs/install` equality before CI reported the failure.
- Reran `./tests/run_package_tests.sh`, `./tests/run_smoke_tests.sh`, and
  `./tests/run_tests.sh` with installed `novim` hash/version guards; all local
  checks passed, including 59/59 integration tests and 9/9 smoke tests.
- Ran `bash -n`, PyYAML workflow structure checks, `cmp install.sh docs/install`,
  `git diff --check`, JSON validation, and read-only installed target
  mode/hash/version verification.
- Reviewed the post-merge CI log, which failed only at ShellCheck `SC1003` on
  `install.sh:171`; no other CI job was present.

All local and CI evidence above is explicitly separated from hosted release,
production, recovery-service, and customer-acceptance evidence.

## Delivery decision

`CHANGES_REQUESTED` after PR #31 merge. The merge is retained; no force-push
or revert is performed. Do not mark TASK-017 accepted or issue TASK-018 until
the same-task installer correction passes ShellCheck and a follow-up review.

## Next action

Return TASK-017 to `$stateless-implementer`: make the backslash check in
`install.sh` and `docs/install` ShellCheck-clean without weakening archive
validation, rerun the focused/full suites, then open the necessary follow-up
traceability PR and request review.
