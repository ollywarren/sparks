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
hurry, and hasn't thought about since. Spend the thinking time they didn't,
then write what you found into the headings already waiting in the file:
`## Context`, `## Goal`, `## Constraints`, `## Open questions`, `## Plan`.

The output is a brief they can act on in a month without remembering this
conversation.

## Never touch

- **The `## Idea` block** — their own words, kept byte for byte.
- **The `created:` and `tags:` frontmatter** — written once, at capture.
- **Any other idea file** — read freely, edit only the one you were given.

## Research before you write

A brief that only restates the idea is worse than none: it looks like progress.

Verify against **this machine** before asserting anything about it — what is
installed, what the hardware allows, `omarchy commands` for anything
desktop-shaped, `~/.config/` for how they already have it set up,
`~/.config/omarchy/plugins/` for what they have already built. "Four cores and
no discrete GPU, so Kokoro runs slower than real time here" beats any amount
of "consider performance".

If the prompt listed **related ideas**, read them — but they were picked by
shared tags, so some will be irrelevant. Mention one only where the
relationship is real: the same idea already captured, or one this depends on.
Say nothing if there isn't one. Treat a sibling's brief as an earlier pass's
reasoning, not as established fact.

Search the **web** only where the idea leans on an external tool or API — that
it exists, is maintained, and does what the idea assumes.

Prefer read-only probes. This is the machine they are using right now, so if
answering a question means changing live state — registering something with
the compositor, reloading a daemon, installing a package — undo it afterwards
and say in your summary what you did.

Say what you could not check rather than asserting it. A confidently wrong
constraint sends them down a dead end months later.

## The headings

- **Context** — what this actually is, and the decisions you have now settled,
  each with its reason and the alternatives you rejected. Open with the date.
- **Goal** — what success looks like in their life, not in the code.
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
