---
name: spark-build
description: >
  Start building a project from a Sparks planning brief — a BRIEF.md in a fresh
  git repo, symlinked back to the idea file it came from. Use when handed a
  scaffolded but empty project whose spec is BRIEF.md, typically launched by the
  Build button in the Sparks bar widget or by `sparks build`.
  Triggers: spark, sparks, BRIEF.md, build this idea, start this project,
  sparks build, planning brief, "## Plan".
---

# Building from a Spark

You are in a project directory that contains nothing but a fresh git repo and
`BRIEF.md`. That brief is the spec: an idea the user captured, then had
researched into a plan. Your job is to start building it.

`BRIEF.md` is a **symlink back into the user's ideas folder**. Editing it edits
the idea itself, which is what makes progress show up in their Sparks list — so
edit it deliberately, and never replace it with a regular file (`>` redirects
and some editors will break the link; append or edit in place instead).

## Before writing any code

1. **Read the whole brief.** `## Context` explains what this is and what was
   already decided. `## Constraints` is binding. `## Plan` is your starting
   order of work.
2. **Settle the open questions.** `## Open questions` exists because those
   points needed a person. Ask them. Do not guess, and do not quietly pick the
   convenient answer.
3. **Confirm the plan.** Say what you are about to build, in what order, and
   what the first commit will contain. If research since the brief was written
   changes something — a library is dead, an API moved — say so now rather than
   working around it silently.

Only start writing files once the user has answered and agreed.

## While building

- **Treat `## Constraints` as binding.** They were established against this
  actual machine. If one turns out to be wrong, say so explicitly and get
  agreement before designing around the new fact.
- **Keep `## Plan` current.** As steps land, update them in `BRIEF.md` — mark
  what is done, add steps the work turned up. The brief stays the honest
  description of where the project is, so the user can reopen it in a month and
  know.
- **Never rewrite `## Idea`.** Those are the user's original words. The same
  goes for `created:` and `tags:` in the frontmatter.
- **Commit as you go**, with messages that would make sense to someone reading
  `git log` next year. Do not push anywhere or create remotes unless asked.

## Finishing a session

Leave the repo in a state that runs, or say plainly that it doesn't and what is
missing. Update `## Plan` before you stop, then summarise for the user: what
works now, what you decided along the way, and what the next step is.
