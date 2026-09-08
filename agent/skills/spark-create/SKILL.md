---
name: spark-create
description: >
  Make a Sparks idea real, working from the planning brief it already has — a
  BRIEF.md in a fresh workspace, symlinked back to the idea it came from. Use
  when handed an empty workspace whose spec is BRIEF.md, typically launched by
  the Create button in the Sparks bar widget or by `sparks create`.
  Triggers: spark, sparks, BRIEF.md, make this idea real, start this idea,
  sparks create, planning brief, "## Plan".
---

# Creating from a Spark

The workspace holds a fresh git repo and `BRIEF.md`, and nothing else. That
brief is the spec: an idea the user captured, then had researched into a plan.

An idea can be anything — a document, a set of images, a web app, a desktop
plugin, a room that needs painting. Read the brief before you assume which.
What you produce should suit the thing, not the container: the workspace is a
folder with version history, not a promise that this is a software project.

Plenty of briefs are satisfied by writing something down. If the `## Plan` is
mostly research — compare these options, price this up, find out whether this
is possible — then the deliverable is that research, laid out so they can
decide from it. Don't reach for code because there is a git repo.

`BRIEF.md` is a **symlink to the user's own idea note**, not a copy. Editing it
in place keeps their note and this workspace's spec the same document — never
`>` over it or let an editor replace it, which silently breaks the link and
leaves them with a note that has stopped tracking the work.

## Before you make anything

1. Read the whole brief. `## Context` holds decisions already settled.
2. **Answer `## Open questions` by asking them.** Those are there because they
   needed a person. Don't guess, and don't quietly take the convenient option.
3. Say what you are about to make, in what order, and what the first piece
   will be. If something has changed since the brief was written — a tool is
   dead, a source moved, a price is now wrong — say so now rather than silently
   working around it.

Start once they have answered.

## While working

- `## Constraints` are binding; they were established deliberately. If one
  turns out to be wrong, say so and agree a new approach rather than designing
  around it quietly.
- Keep `## Plan` current — mark what is done, add steps the work turned up. The
  brief stays the honest account of where this has got to.
- Never rewrite `## Idea`, `created:` or `tags:`.
- Commit as you go, with messages that will make sense in a year. That is what
  makes your work undoable, whether it is code or a manuscript. No remotes or
  pushes unless asked.

Leave the workspace in a state they can pick up: working, or plainly labelled
as unfinished with what is missing.
