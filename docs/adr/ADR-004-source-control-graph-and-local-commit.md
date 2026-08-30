# ADR-004: Source Control Graph, Selectable Comparisons, and Local Commits

- Status: `ACCEPTED FOR IMPLEMENTATION`
- Date: 2026-08-30
- Scope: successor Git workbench milestone

## Decision

Extend the accepted local Git workbench in ordered successor slices:

1. Keep the Git Source Control area terminal-first and split its left column
   horizontally. The current changes/status and staging surface is above; the
   current branch's commit graph is below.
2. Render the full commit ancestry reachable from the current branch, showing
   merge nodes and available branch/decorate information. Selecting history
   entries is read-only and must not check out or mutate a branch.
3. Let the user choose two distinct revision/location endpoints for a
   comparison. The endpoints may be current working tree, `HEAD`, a branch or
   another graph-visible commit/ref supported by the local repository. The
   selected endpoints become the old/new comparison panes; the existing
   working-tree-versus-`HEAD` view remains the default current-change view.
4. Add a local write surface limited to staging, unstaging, and committing
   staged changes with a user-entered commit message. Commit actions operate
   only on the local repository and refresh the Source Control view afterward.

The first write-capable surface does not include push, pull, fetch, merge,
rebase, branch checkout, discard, amend, remote synchronization, credential
handling, or plugin installation. Partial-line staging is also not implied by
this decision; the first staging slice operates at the file level unless a
later task explicitly expands it.

## Rationale

The current Diff view makes the latest working-tree state easy to inspect but
cannot show the full evolution that led to it. A graph below the current
changes follows the useful parts of VS Code's Source Control workflow while
keeping the terminal workbench local. Two explicit endpoints avoid silently
choosing a comparison baseline when the user wants to inspect a commit, merge,
branch, `HEAD`, or the working tree.

Local stage/unstage/commit is the smallest useful write surface for creating
focused checkpoints. Remote and history-rewriting operations carry different
authority and recovery risks and stay out of scope.

## Consequences

- `TASK-012` can implement the left-column Source Control layout, graph, and
  two-endpoint read-only comparison without adding branch mutation.
- `TASK-013` can implement file-level stage/unstage and local staged commits
  behind explicit non-empty-message and error handling.
- The current `HEAD` diff, untracked-file handling, pane geometry, isolated
  runtime, and no-default-network boundaries remain preserved.
- Git subprocesses now need a clear distinction between read-only revision
  reads and the explicitly authorized local index/commit mutations.
