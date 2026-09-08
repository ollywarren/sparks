---
name: spark-build
description: >
  Start building a project from a Sparks planning brief — a BRIEF.md in a fresh
  git repo, symlinked back to the idea it came from. Use when handed a
  scaffolded but empty project whose spec is BRIEF.md, typically launched by the
  Build button in the Sparks bar widget or by `sparks build`.
  Triggers: spark, sparks, BRIEF.md, build this idea, start this project,
  sparks build, planning brief, "## Plan".
---

# Building from a Spark

The project directory holds a fresh git repo and `BRIEF.md`, and nothing else.
That brief is the spec: an idea the user captured, then had researched into a
plan.

`BRIEF.md` is a **symlink to the user's own idea note**, not a copy. Editing it
in place keeps their note and this project's spec the same document — never `>`
over it or let an editor replace it, which silently breaks the link and leaves
them with a note that has stopped tracking the work.

## Before writing code

1. Read the whole brief. `## Context` holds decisions already settled.
2. **Answer `## Open questions` by asking them.** Those are there because they
   needed a person. Don't guess, and don't quietly take the convenient option.
3. Say what you are about to build, in what order, and what the first commit
   will contain. If something has changed since the brief was written — a
   library is dead, an API moved — say so now rather than silently working
   around it.

Start writing files once they have answered.

## While building

- `## Constraints` are binding; they were established against this machine. If
  one turns out to be wrong, say so and agree a new approach rather than
  designing around it quietly.
- Keep `## Plan` current — mark what is done, add steps the work turned up. The
  brief stays the honest account of where the project has got to.
- Never rewrite `## Idea`, `created:` or `tags:`.
- Commit as you go, with messages that will make sense in a year. No remotes or
  pushes unless asked.

Leave the repo in a state that runs, or say plainly that it doesn't and what is
missing.
