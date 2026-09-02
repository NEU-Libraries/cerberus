# Cerberus developer docs

Per-component reference that has to version with the code.

## What belongs here

Explanation a developer needs *while changing a specific file*, and that is too
long to sit inside it: routing tables, retry-safety arguments, wire contracts
with Atlas, and the reason a design rejected the obvious alternative.

Each page names the source files it covers. Those files carry a one-line pointer
back, so you can find either from the other.

## What belongs elsewhere

| Audience or need | Home |
|---|---|
| A repository user, or a UAT tester | the user guide (`cerberus-guide`) |
| A Rails developer new to repository software | the developer primer (`cerberus-primer`) |
| A rule that code can check | a spec, not prose |

The primer teaches vocabulary and concepts, and links to source. These pages
assume you already have the file open.

Prefer a spec to a page here whenever the claim is testable. A spec fails when
someone breaks it; a page does not.

## Writing standard

Plain language, per ISO 24495-1, matching the primer:

- Put the answer first, the evidence after.
- Use the active voice, and name the actor.
- Use one term for one thing. If it is a Blob in the code, call it a Blob here.
- Reference code as `path:line` so a reader can open it.
- State a constraint as a constraint. Write "Atlas appends a Blob on every
  `FileSet.update`", not "be careful with updates".

## The density target

A source file should keep its comments under about 35% of its non-blank lines.
That is a target for prose that belongs on a page here, not a rule to satisfy by
deleting knowledge. If a comment would cost someone a bug, keep it and go over.

**Files with fewer than 25 lines of code are exempt.** Density measures comments
against code, so a file that declares rather than computes has no denominator to
earn a budget with. `app/models/current.rb` is the clearest case: twenty comment
lines over seven lines of code, and each one names a header's behaviour on the
wire, including that `view_as_nuid` is never sent as a write header. Forcing that
file under the target would make it worse at the thing the target exists to
improve.

## Adding a page

1. Group by the thing a developer is changing, not by the class name. Several
   files that share one pipeline belong on one page.
2. Name the source files at the top of the page.
3. Leave a pointer in each source file: one line, naming this path.
4. Keep in the source file only what someone editing that specific line must
   not miss. Everything else comes here.
