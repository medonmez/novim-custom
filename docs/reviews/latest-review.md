# Latest Review

Updated: 2026-08-31
Task ID: `TASK-017`
Local verdict: `APPROVED`
Delivery policy: `LIGHTWEIGHT`
Implementation baseline: `8c1617c` (post-merge CI failure record; the
recorded expected baseline `9904324ba79c666be46e6efe92e932eb1ea8e2d4` is an
ancestor)
Reviewed head: `369dedbda70b551fa3dbfa84e46bb8f45c8856ed`
Implementation candidate: `369dedbda70b551fa3dbfa84e46bb8f45c8856ed`
Task branch: `task/TASK-017-oh-my-code-package-installer`
Previous pull request: `https://github.com/medonmez/novim-custom/pull/31`
(`MERGED` at `f070a7446f6fe93d2e1ba32e15d2e0fe45f27ff8`)
Follow-up pull request: pending

## Review result

The actual follow-up diff was inspected. It changes only the three
backslash-manifest checks, the focused hostile-archive fixture coverage, and
the current-task handoff. The new `grep -qF "\\"` pattern is a one-character
fixed-string search. A direct probe gave the same results as the former
`grep -q '\\'` BRE: a manifest entry containing a backslash is rejected and
a clean manifest is accepted.

The previously reported CI failure is therefore corrected without weakening
archive validation. The local review is approved for delivery. The local
environment does not have a `shellcheck` executable, so the previously failing
ShellCheck job must be observed as successful on the follow-up PR before the
merge and acceptance decision.

## Findings

No remaining code-level finding in the reviewed follow-up diff.

## Resolved prior findings

- The source-symlink leak remains resolved by `validate_source_tree` in
  `bin/oh-my-code-package:95-127`, before copying or archive creation.
- The offline VERSION identity gap remains resolved by
  `bin/oh-my-code-package:298-307`, before any target mutation.
- The post-merge CI `SC1003` regression at `install.sh:171` is corrected at
  `install.sh:171`, `docs/install:171`, and
  `bin/oh-my-code-package:226` with equivalent fixed-string matching.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Byte-identical package and overwrite refusal | PASS | Guarded package suite; SHA-256 `7b9062c70e462289e16f9db1f8ea4b0cb276d169f11693f678b31bf28a1b9a7e` remained stable. |
| Allowlisted archive and source fail-closed boundary | PASS | Manifest assertions and source symlink/non-regular validation pass. |
| Public installer validation, root, and links | PASS | Local happy paths pass; fixture server observes exactly the archive and checksum GETs. |
| Collision and failure safety | PASS | Collision, malformed, traversal, absolute, backslash, symlink, allowlist, VERSION, checksum, 404, and unreachable-host cases fail closed with unchanged targets. |
| Launcher identity, isolation, and installed `novim` boundary | PASS | Package, smoke, and full suites pass; installed `novim` guard remains unchanged. |
| Release workflow and `bin/novim` boundary | PASS | Workflow structure validation passes; no tag/release was run; checkout `bin/novim` hash is unchanged. |
| Required validation including the prior ShellCheck regression | PASS locally; remote check pending | `bash -n`, YAML structure, package, smoke, full suite, installer-copy comparison, direct pattern-equivalence probe, and `git diff --check` pass. Local ShellCheck is unavailable; follow-up PR CI is the required remote confirmation. |

## Validation performed

- Inspected `AGENTS.md`, the repository routing contract, project state,
  current task, backlog, ADR-006, and the prior CI-failure review.
- Confirmed a clean task branch at `369dedb`, two commits ahead of the remote
  task branch, with no unrelated changes. The prior PR #31 is merged; the
  follow-up has not yet been pushed or opened.
- Reran `./tests/run_package_tests.sh`: deterministic archive, source-tree
  symlink rejection, hostile `backslash-entry` rejection in the offline
  helper, installer collision/failure checks, fixture-server download and
  checksum checks, workflow structure, and invariance all passed.
- Reran `./tests/run_smoke_tests.sh`: 9/9 passed.
- Reran `./tests/run_tests.sh`: 59/59 integration tests plus package and smoke
  runners passed.
- Ran `bash -n` through the relevant scripts, verified
  `cmp -s install.sh docs/install`, verified the direct old/new grep behavior,
  and confirmed `git diff --check` is clean.
- Read-only invariance guards before and after the suites confirmed checkout
  `bin/novim` SHA-256
  `cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321` and the
  installed release target SHA-256
  `5955e1f2c223d13b024e263dca412f1acb96b69d4168b26b3fa3f7b14c1de26a`, mode
  755, reporting `novim 0.1.7`. The working-tree status also remained
  unchanged.

All evidence above is local or synthetic fixture evidence. It is not hosted,
production, recovery-service, or customer-acceptance evidence.

## Incident and recovery record

During the earlier fixer investigation, a temporary probe wrote checkout
`bin/novim` bytes through the `~/.local/bin/novim` symlink onto the installed
`~/.local/share/novim/bin/novim` target. The resulting `novim 0.1.0` output was
incorrectly treated as unchanged because the post-mutation measurement used
the damaged file and provenance was inferred from README/LICENSE/VERSION
instead of the binary.

The target was restored only after the upstream `link2004/novim` v0.1.7
release asset matched the recorded binary hash
`5955e1f2c223d13b024e263dca412f1acb96b69d4168b26b3fa3f7b14c1de26a`. This
review performed no write to the installed release. The guarded validation
reruns preserved that hash and version. `bin/novim` and the normal Neovim
configuration were also read-only checked and remained unchanged.

The incident is recorded here as a local repository review and recovery
record. It is not a hosted, production, recovery-service, or
customer-acceptance claim.

## Delivery decision

`APPROVED` for the follow-up PR. Push the two local commits and open one
follow-up PR against `main`. Because the previous merged PR exposed this
exact CI regression, do not merge until the follow-up ShellCheck check is
successful. Do not create a tag, publish a release, or perform the hosted
repository rename; those remain TASK-019 scope.

## Next action

Push `task/TASK-017-oh-my-code-package-installer`, open the follow-up PR, and
verify its ShellCheck result. After the remote default branch contains the
follow-up merge, reconcile TASK-017 as `ACCEPTED` and only then issue TASK-018.
