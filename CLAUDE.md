# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Tenjin is a Rails 7.2 quiz platform for schools. Students answer questions, earn points, and compete on leaderboards. Teachers manage homework and classrooms. School admins sync rosters from Wonde (a UK school MIS API).

Toolchain: Ruby `~> 3.4.9`, Node 22, pnpm, PostgreSQL. `config.load_defaults 7.2` with `active_storage.variant_processor = :mini_magick` retained as an explicit override (libvips not on infra).

## Architecture

### Authorization: Pundit (enforced globally)

`ApplicationController` runs `verify_authorized` (non-index) and `verify_policy_scoped` (index) as after-actions on every request. Every controller action must call `authorize` or `policy_scope`. Policies live in `app/policies/`.

### School roster sync via Wonde

Schools sync their student/teacher rosters from a UK MIS via the Wonde API (`wondeclient` gem for the REST API; `omniauth-wonde` gem for SSO). Sync runs as a background job (`SyncSchoolJob`) using Delayed Job. The sync marks existing users `disabled: true` first, then re-enables matching records.

### Frontend: Hotwired (Turbo + Stimulus), with Alpine.js sprinkles

Stimulus controllers in `app/javascript/controllers/` drive per-page behaviour. Notably `multiple_choice_question_controller.js` and `short_response_question_controller.js` `PUT` to `QuizzesController#update`, which delegates to `Quiz::CheckAnswer` and returns JSON — answer correctness is decided server-side; the client only paints the result.

### Services layer

Business logic is split across three layers:

- **`app/services/<domain>/<name>.rb`** — service objects, organised by domain. Inherit either:
  - **`ApplicationCommand`** for writes that may fail. `#call` returns an `ApplicationCommand::Result` (`success`, `payload`, `error`). Pattern-match at call sites with `case result in {success: true, ...}`.
  - **`ApplicationService`** for side-effect-only operations (broadcast, batch updates, fire-and-forget jobs). Returns raw values or `nil`.
- **`app/queries/<domain>/<name>.rb`** — read-only data aggregation. Lazy memoized POROs. Construct cheap, evaluate on access. No `.call`.
- **`app/serializers/<domain>/<name>.rb`** — shape Ruby objects into JSON payloads.

Controllers should call into these rather than embed domain logic.

## Testing

`NO_COVERAGE=1` skips SimpleCov.

## Code comments

Comments describe the code as it stands — never the process that
produced it.

- No task numbers, phase names, plan steps, PR or issue numbers, or
  "the old version".
- Explain *why*, not *what*. Skip inline comments that restate the code.
- Keep them short. Never two lines where one will do.

      Bad:  # Phase 2: add retry wrapper (task 3.1)
      Good: # Upstream 503s under load

**Exception: every class and module opens with a one-line description**
(`# Stores a policy file that has been customised for a site`), as the
existing code does. That line says what the class *is*; the why/what
rule governs the comments inside it.

Directives are not comments: `# frozen_string_literal`, `# :nocov:`,
`rubocop:disable`, YARD tags, and the issue reference on a `pending`
or `test.failing` marker — the number is what makes the marker legal
under the `rspec-quality` skill's Rule 18, and it leaves with the
marker. In Slim, `/` is a code comment; `/!` is rendered into the page
as an HTML comment.

A rejected alternative or a transitional setting is worth recording,
but as a present-tense property of the design ("opt out of the 7.0
:vips default; image processing stays on ImageMagick"; "only remove
this rotation after a backfill has re-signed every stored body"),
never as history ("vips used to break thumbnails").

**Put a comment where its question is asked.** Provenance for a
constant belongs beside the constant, not beside a predicate that
merely names it. A constraint coupling two modules belongs at the site
an edit would break, naming the other end — a set that must stay in
lockstep with a table elsewhere says so where someone would extend the
set, because that is where the reader is standing when they break it.

**Keep terms of art uniform and self-explaining.** A shared term should
be inferable by a reader meeting it cold, and mean the same thing in
source and tests. Name what a thing *is* rather than when it arrived:
an *sgid signed under the other digest* still means the same thing if
the digest flip is reverted; "a legacy sgid" silently changes referent.

## Commits and pull requests

Every commit subject and PR title carries a Conventional Commits prefix, an imperative verb, and at most 70 characters. The repository squash-merges from the PR title, so an unprefixed title lands on `main` and cannot be fixed without a force-push the ruleset forbids. Before writing a commit message, PR title, or PR description, invoke the `commit-conventions` skill for the prefix table, body rules, and description format.
