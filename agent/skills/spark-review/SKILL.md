---
name: spark-review
description: >
  Research a captured idea and turn it into a planning brief, in place, in the
  idea's own Markdown file. Use when handed a Sparks idea file to review, plan,
  flesh out, or "turn into a brief" — typically launched by the Review button in
  the Sparks bar widget or by `sparks review`.
  Triggers: spark, sparks, idea file, planning brief, review this idea, flesh
  out this idea, ~/Notes/ideas, "## Open questions", sparks review.
---

# Reviewing a Spark

A Spark is one Markdown file holding a thing the user thought of, typed in a
hurry, and has not thought about since. Your job is to spend the thinking time
they didn't have — research it properly, then write what you found back into
the same file under headings that are already waiting for it.

The output is a brief a person can act on weeks later without remembering this
conversation.

## The file

```markdown
---
created: 2026-09-07T08:24:15+01:00
tags: omarchy,plugin,tts
status: new
---

## Idea
<what they typed, verbatim, hashtags and typos and all>

## Context


## Goal


## Constraints


## Open questions


## Plan
```

## What you must not touch

- **The `## Idea` block.** Those are the user's own words. Never reword,
  correct, tidy, expand or summarise them. They stay byte-for-byte identical.
- **The `created:` and `tags:` frontmatter.** Written once at capture time.
- **Other idea files.** Read them freely; edit only the one you were given.

Everything from `## Context` down is yours to write.

## Research before you write

A brief that only restates the idea is worse than no brief — it looks like
progress and isn't. Go and find things out first.

- **Check this machine.** Is the tool already installed? What does the hardware
  actually allow? `omarchy commands` for anything desktop-shaped; look in
  `~/.config/` for how the user already has it set up; look in
  `~/.config/omarchy/plugins/` for what they have already built. Concrete beats
  general: "4 cores, no discrete GPU, so Kokoro runs at worse than real time
  here" is worth ten paragraphs of "consider performance".
- **Read the sibling ideas** in the same folder. The user may have already
  decided something this idea depends on, or already had this idea. Say so if
  they did, and build on it rather than starting the argument again.
- **Search the web** when the idea leans on an external tool, API or library —
  and only then. Check it still exists, is maintained, and does what the idea
  assumes.
- **Report what you verified and how.** If you could not check something, say
  it is unverified rather than asserting it. A confidently wrong constraint
  sends the user down a dead end months later.

## What goes under each heading

**`## Context`** — what this actually is, once you understand it. Start with
the date you reviewed it (`Planned 2026-09-08.`). Name the thing properly if
the captured text called it the wrong thing, and say why the rename. Record
prior art you found, in the user's own work and outside it. This is the section
that carries decisions: pick one, give the reason, and name the alternatives
you rejected.

**`## Goal`** — what success looks like in the user's life, not in the code.
One or two sentences of intent, then a concrete "success looks like…" that
would be obvious if it happened.

**`## Constraints`** — hard limits you established, each with the evidence.
Hardware, platform rules, what an API will and won't give you, what is already
installed and what isn't. This section is why the plan is the shape it is.

**`## Open questions`** — genuine forks only, where you need the user's
judgement and no amount of research would settle it. Taste, priorities, scope.
Not a list of things you could have looked up. Two or three is usually right;
if you have eight, most of them are research you skipped.

**`## Plan`** — ordered, concrete steps with real paths and real commands. Each
step should be startable without rereading everything above it.

## Style

Write it the way the sibling ideas in the folder are written: prose that argues
its case, not bullet soup; specific numbers and paths; opinions with reasons
attached. Bold a lead-in phrase where a paragraph makes a distinct point. No
meta-commentary about being an agent, no "as an AI", no hedging filler, and
nothing that reads like a report about the file rather than the file itself.

Length follows the idea. A small one deserves a short brief.

## Finishing

Mark it reviewed — through the helper script, never by hand-editing
frontmatter, so the parsing stays consistent:

```bash
<helper script> set <ideas folder> <idea file> status planned
<helper script> set <ideas folder> <idea file> planned $(date +%F)
```

(The prompt that launched you names both paths and the helper script.)

Then tell the user, in the terminal, in a few lines: what you decided and why,
what you verified on the machine, and what is still open and waiting on them.
Do not paste the whole brief back at them — it is in the file, and they can
open it from the Sparks bar icon.

If the brief already has content — you are re-reviewing — revise and extend it
instead of replacing it. Keep what is still true, correct what isn't, and say
in your summary what changed.
