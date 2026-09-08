---
name: spark-review
description: >
  Research a captured idea and turn it into a planning brief, in place, in the
  idea's own Markdown file. Use when handed a Sparks idea file to review, plan,
  or flesh out — typically launched by the Review button in the Sparks bar
  widget, or by `sparks review`.
  Triggers: spark, sparks, idea file, planning brief, review this idea, flesh
  out this idea, "## Open questions", sparks review.
---

# Reviewing a Spark

A Spark is one Markdown file holding something the user thought of, typed in a
hurry, and hasn't thought about since. It could be about anything at all.
Spend the thinking time they didn't, then write what you found into the
headings already waiting in the file:
`## Context`, `## Goal`, `## Constraints`, `## Open questions`, `## Plan`.

The output is a brief they can act on in a month without remembering this
conversation.

## Never touch

- **The `## Idea` block** — their own words, kept byte for byte.
- **The `created:` and `tags:` frontmatter** — written once, at capture.
- **Any other idea file** — read freely, edit only the one you were given.

## Research before you write

A brief that only restates the idea is worse than none: it looks like progress.

An idea can be anything — a document, a set of photographs, a web app, a
desktop plugin, a trip, a gift. Work out what this one is before deciding what
counts as research.

**Check what can actually be checked.** Part of any idea is verifiable and the
rest is judgement; find that line and stay on the right side of it. Concrete
always beats general — a real price, a real date, a real page count, "four
cores and no discrete GPU, so that model runs slower than real time here" —
against any amount of "consider performance".

Look at what they already have before proposing something new: their own
files, notes and earlier attempts at the subject. Where the idea touches this
machine, check the machine rather than assuming — what is installed, what the
hardware allows, `omarchy commands` for anything desktop-shaped, `~/.config/`
for how they have it set up, `~/.config/omarchy/plugins/` for what they have
already built.

If the prompt listed **related ideas**, read them — but they were picked by
shared tags, so some will be irrelevant. Mention one only where the
relationship is real: the same idea already captured, or one this depends on.
Say nothing if there isn't one. Treat a sibling's brief as an earlier pass's
reasoning, not as established fact.

Search the **web** only where the idea leans on something outside their
control — a tool, a service, a supplier, a venue — to confirm it exists, is
current, and does what the idea assumes.

Prefer read-only probes. This is the machine they are using right now, and the
world is the one they live in — so if answering a question would change
something real, don't. Where you must, keep it reversible: registering
something with the compositor, reloading a daemon, installing a package. Undo
it afterwards and say in your summary what you did. Never anything that
commits them — no messages sent, no accounts made, no money spent.

Say what you could not check rather than asserting it. A confidently wrong
constraint sends them down a dead end months later.

## The headings

- **Context** — what this actually is, and the decisions you have now settled,
  each with its reason and the alternatives you rejected. Open with the date.
- **Goal** — what success looks like in their life, not in the thing itself.
- **Constraints** — the hard limits you established, each with its evidence.
- **Open questions** — only genuine forks needing their judgement. If you have
  eight, most of them are research you skipped.
- **Plan** — ordered, concrete steps with real paths.

Write it like the briefs already in the folder: decisions with reasons, not
bullet soup. Length follows the idea; a small one deserves a short brief.

## Finishing

Run the `sparks reviewed …` command the prompt gave you, then tell them in a
few lines what you decided, what you verified, and what is still open. Don't
paste the brief back — it is in the file, and they can open it from the bar.

Re-reviewing an idea that already has a brief means revising it: keep what is
still true, correct what is not, and say what changed.
