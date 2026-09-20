---
name: rspec-quality
argument-hint: <spec file or directory>
description: >
  Use when writing, refactoring, cleaning up, or reviewing RSpec specs
  in this Rails app — authoring a new model, request, system, or policy
  spec; deciding which layer should cover a behaviour ("how should I
  test this?"); or tidying existing specs ("refactor specs", "clean up
  specs", "review spec naming", "tidy up rspec").
---

Refactor the target RSpec spec file(s) to apply the best practices
described below. Work through each rule systematically, proposing and
applying changes file by file.

**Arguments provided**: $ARGUMENTS

If the argument is a file path, read and refactor that file. If it is a
directory, find all `*_spec.rb` files within it and work through them
one at a time. If no argument is provided, ask what to refactor.

**Authoring a new spec instead of refactoring one?** Same standard,
different entry point: there's no file to read, delete from, or relocate,
so the removal workflow drops away and the rules become a *writing*
checklist rather than a cleanup pass.

| Rules | In authoring mode |
|---|---|
| Quality rules **1–15, 17, 19, 20, 21, 22** | **Apply as you write** — the bar for any spec, including 17's "no no-signal padding." |
| Layer/altitude rules **16, 16a, 16b** | **Use as design input, before writing:** pick the cheapest correct layer for the behaviour (16), prove shared wiring once rather than authoring a redundant browser smoke (16a), and remember a request spec can't pin form wiring (16b — caveat below). |
| Rule **18**, Step 1's "read the file", Step 3's "list violations", the suite-level check | **Skip** — they act on code that doesn't exist yet. |

Even with no file to read, still read `spec/support/default_creates.rb`
and the `rails_helper` globals your spec will build on, so you don't
duplicate or shadow their setup (Rule 20).

**Writing a request spec for a `create`/`update` form action?** Rule
**16b**'s caveat holds even though you skip the rule itself: a request
spec's params are *author-written*, so it proves the controller honours
the params you supplied — **not** that the real form renders and posts
them. Don't paper over that gap with `have_field` padding (Rule 17);
pinning the form wiring is a separate, deliberate `:js` / rack_test
system-spec choice.

**Running this across many files.** A single invocation walks a
directory sequentially and is always safe. To parallelise, do **not**
split one file per agent in a shared worktree — Rules 16 / 16a / 16b
relocate many system specs into the *same* request spec, and Rule 5
edits shared factories, so file-level agents silently overwrite each
other. Either give each agent its own git worktree and merge, or
partition by resource (one agent owns `system/<resource>/*` and its
`requests/<resource>_request_spec.rb`). Run the suite-level check once
after all agents finish.

---

## Project profile & example conventions

**A note on the examples.** Snippets use this app's own domain — school,
classroom, homework, quiz, subject, topic, question, answer — so a model,
factory, or path named in a snippet is real and can be checked against
the codebase. Some snippets are simplified rather than copied from a
spec: treat them as shapes to follow, not text to grep for.

**Project facts the rules depend on.** Load-bearing facts are stated
inline in the rule that reasons over them; this list is the index. When
one of these changes, re-point the rule it names.

- **System-spec driver.** `spec/rails_helper.rb` drives system specs
  with `rack_test` and switches to Cuprite for `js: true`, in two
  `config.before(:each, type: :system)` hooks. Every system spec
  currently carries `:js`; a spec that needs no JavaScript drops the tag
  and runs at rack level. → load-bearing for **Rule 16b** and **Rules
  16 / 16a**.
- **Request-spec idiom.** Request specs sign in with Devise's `sign_in`
  (`Devise::Test::IntegrationHelpers` is included for `type: :request`)
  and assert on the body either as a string
  (`expect(response.body).to include(...)`) or through Capybara matchers
  on `Capybara.string(response.body)` (`have_css`, `have_link`, ...).
  Relocation targets in **Rule 16** use the Capybara form; the
  `[system + request]` rules apply to it. An action that answers an XHR
  with JSON (`request.xhr?`, `show.json.erb`) is asserted through
  `response.parsed_body` after `get path(format: :json), xhr: true`.
  → **Rules 10, 13, 16, 21**.
- **JS test runner.** jest, run with `pnpm test:js`; `roots:
  ["spec/javascript"]`, jsdom environment, `@swc/jest` transform.
  `spec/javascript/controllers/*.test.js` instantiate a Stimulus
  controller directly (`new FormController({ scope: { element } })`).
  An Alpine component registered with `Alpine.data("name", factory)` is
  reached by `jest.mock("alpinejs")`, importing the module, and taking
  `factory` from `Alpine.data.mock.calls[0][1]`; mock
  `channels/consumer` the same way where the component subscribes.
  → **Rule 16**'s client-side row, **Step 3**.
- **Cable adapter.** `config/cable.yml` sets `adapter: test` for the
  test environment; it inherits Async, which posts each delivery to the
  event loop's thread pool. → **Rule 12**'s negative-after-trigger
  ordering.
- **Form param conventions.** Association choices post `*_id` from a
  `select` (`topic_id`, `classroom_id`, `lesson_id`), roles post the
  `role` enum, and question answers post `answers_attributes`; the
  controller `permit`s each. There are no `*_ids` checkbox groups.
  → **Rule 16b**'s "association / choice input" predicate.
- **Linter.** StandardRB with no config file: `bundle exec standardrb
  --fix <file>`. Standard ships no RSpec, Capybara, or FactoryBot cops,
  so Rules 5, 10 and 15 are applied by hand. → **Step 2**.
- **Factories.** FactoryBot in `spec/factories/`; domain-state variants
  are traits, with `to_create { |i| i.save!(validate: false) }` for
  states that fail validation (`:overdue` on `homework`). Names come
  from FFaker: `sequence(:name) { |n| "#{FFaker::Lorem.word} #{n}" }` on
  `subject`, a bare `FFaker::Lorem.word` on `topic`, `FFaker::Color.name`
  on `customisation`. → **Rules 5 and 21**.
- **Shared context.** `with default_creates`
  (`spec/support/default_creates.rb`), included through the
  `:default_creates` tag, provides `quiz_subject`, `topic`, `school`,
  `student`, `teacher`, `school_admin`, `classroom` and `super_admin`.
  → **Step 1, Rule 20**.
- **Single-file run.** `NO_COVERAGE=1 bundle exec rspec <path>`.
  → **Step 3**.

---

## Step 1: Read the file

Read the full spec file before making any changes. Build a mental model
of the structure: what shared context it uses, what records are created,
and how tests are grouped.

Also read `spec/support/default_creates.rb` when the spec carries the
`:default_creates` tag, plus any other shared context pulled in via
`include_context`. Read each one so you understand the records and
`let`s it already provides; duplicating setup that a shared context
already supplies is a common smell this refactor removes.

Read the view the spec visits and any JavaScript that fills it, and
answer one question before Pass 1: **is the markup the spec asserts on
server-rendered or built client-side?** A container filled by Alpine,
Stimulus or a `fetch` is empty in `Capybara.string(response.body)`, so
its server half relocates to a request spec on the JSON endpoint and
its client half to jest (Rule 16); server-rendered markup relocates to
`Capybara.string` as the Rule 16 table says. The answer decides every
relocation target in the file, so settle it first.

List every `exact_text:` in the file whose value is not a quoted
String, a Regexp or a `.to_s` call. Each one checks nothing (Rule 21)
and is a candidate for Rule 17's vacuous-original clause. A bare
number under `text:` does filter, but by substring, so it is a Rule 21
collision candidate instead.

---

## Step 2: Apply the rules

The rules are numbered for cross-reference, **not** as a strict 1→22
running order. Apply them in two passes: structural removal must precede
local polish, or you refine tests you then delete or relocate — and the
tests you relocate are created *after* the quality rules would have run,
so they never receive them.

**Pass 1 — decide what survives, and where it lives.** Work only the
removal and relocation rules first: **16, 16a, 16b, 17, 18**. Delete dead
and signal-free tests; relocate coverage to its cheapest correct layer.
Consult Rule **11**'s positive/negative symmetry before deleting — don't drop the only counterpart to an assertion made elsewhere in the
file.

**Pass 2 — refine what's left.** Apply the remaining rules — **1–15, then
19, 20, 21, 22** — to the survivors *and* to the request/model specs Pass 1
created. Naming, setup, `let` / `let!`, matchers, and `shared_examples`
consolidation (19) now only touch tests you are keeping.

Within each pass, take one rule at a time: find all its violations in the
file and fix them together before moving to the next rule.

**Rule scope.** Rules apply to every spec layer unless the heading tags
otherwise. `[system]` rules concern browser/Capybara mechanics (`visit`,
waiting, the DOM) and don't apply to request, model, or unit specs;
`[system → cheapest correct layer]` rules relocate system-spec coverage
to the cheapest layer that still tests the behaviour correctly — usually
a cheaper layer, occasionally kept in system. The Capybara-matcher rules
tagged `[system + request]` (10, 13, 21) apply to request specs that
assert through `Capybara.string(response.body)` (*Project profile*); a
request spec that matches raw `response.body` strings has no Capybara
matchers for them to correct. When refactoring a non-system spec, skip
the `[system]`-tagged rules.

**Spend effort on judgment, not mechanics.** Rules 5, 10, and 15 are
mechanical, but StandardRB ships no RSpec cops (*Project profile*), so
run `bundle exec standardrb --fix <file>` for the Ruby-level corrections
and apply those three rules by hand. Spend your real attention on the
judgment rules a linter can't check: 11, 14, 16 / 16a / 16b, 17, 19, 21,
22.

### Rule 1: describe vs context

- Use **`describe`** for a *thing*: a feature section (`describe
  "challenges"`), an actor role (`describe "as a teacher"`), or a
  component (`describe "homeworks"`). Describe blocks are nouns.
- Use **`context`** for a *state or condition*: always phrased as "when
  X" or "with X". Context blocks are conditions.
- Never use `context "when logging in as X"` — logging in is an action,
  not a state. Use `describe "as a teacher"` instead.
- Never use `context "by default"` — it describes nothing. Name the
  actual default state: `context "with no challenge progress"`, `context
  "with an active homework"`, etc.

### Rule 2: it block naming

- `it` descriptions should describe *observable behaviour*, not
  implementation. "shows assigned classrooms" not "shows which classes
  they are currently assigned to".
- Drop words made redundant by the surrounding context. If the context
  is `"when homework is overdue"`, the test should be `"shows an
  exclamation icon"`, not `"shows overdue homeworks with an exclamation
  icon"`.
- Keep descriptions short. If you need more than ~8 words, the context
  is probably not doing enough work.

### Rule 3: Move visit into before blocks — [system]

- `visit(path)` in a test body, or in a helper method a test body calls,
  is setup, not behaviour. Move it into a `before` block.
- **Timing constraint**: RSpec runs before blocks from outermost to
  innermost, and `let!` is implemented as a before hook in its own
  context. This means a `before { visit }` in an *outer* context runs
  before `let!` declarations in *inner* contexts — so the page is loaded
  before that state exists.
- The safe pattern: put `before { visit }` in the *same* context as the
  `let!` that sets up state, not in a parent context. For nested
  contexts with their own `let!`, add a `before { visit }` to that
  nested context even if the parent context already visits — the second
  visit loads the page with the correct state.
- When multiple tests at the same nesting level all visit the same path
  with no additional setup, group them under a shared context with a
  single `before { visit }`.

### Rule 4: Replace inline setup with nested contexts

When a test body contains setup (triggering a lazy `let`, calling
`update_attribute`, or calling `create`/`create_list`), extract it into
a nested context:

```ruby
# Before
it "shows an exclamation icon" do
  homework.update_attribute(:due_date, 1.day.ago)
  visit(dashboard_path)
  expect(page).to have_css("svg.fa-exclamation")
end

# After
context "when homework is overdue" do
  let!(:homework) { create(:homework, :overdue, classroom: classroom, topic: topic) }
  before { visit(dashboard_path) }

  it "shows an exclamation icon" do
    expect(page).to have_css("svg.fa-exclamation")
  end
end
```

The rule: test bodies should contain only interactions (clicks, form
fills) and assertions — not record creation or attribute mutation.

If the `update_attribute` call is itself the action under test (e.g.,
it triggers a callback you're asserting on), extraction to a `before`
block is still correct — but see Rule 5 for whether to replace it with
`update!`.

### Rule 5: Replace update_attribute with factory attributes or update!

- `update_attribute` skips validations (it saves with `validate: false`)
  but **still runs callbacks** — unlike `update_column`, which skips both.
  The smell isn't the bypass itself; it's doing it *inline and ad-hoc*,
  which hides the invalid state from the reader and scatters the same
  setup across specs. Almost always replace it: set valid state at
  creation, or mutate an existing record with `update!`. When an invalid
  state is genuinely needed, name and centralize the bypass in a factory
  trait (below) instead of inline; the only reason to keep
  `update_attribute` is the callback-under-test exception below.
- If the attribute is expressible at factory creation time (e.g.,
  `due_date`), create the record with it via a factory trait, nested
  factory, or attribute override instead — but only when you don't depend
  on an *update* callback firing, since creating fires `after_create` /
  `after_save`, never `before_update` / `after_update`.
- If the mutation is to a record that must already exist (e.g., updating
  a `HomeworkProgress` that was created as a side-effect), use `update!`
  in a `before` block instead. `update!` runs validations and callbacks.
- **Exception — callback under test blocked by validation:** If the spec
  is testing a `before_update` callback and `update!` would fail
  validation before the callback can run, keep `update_attribute` — it is
  the only option that fires the *update* callback while skipping
  validation (a factory fires create callbacks, not update ones; `update!`
  enforces validation). This happens when the model has a validation that
  requires state the callback itself is responsible for creating (a
  chicken-and-egg ordering problem: validation fires before
  `before_update`). This applies whether the
  `update_attribute` is in the test body or has already been extracted to
  a `before` block by Rule 4. Do not attempt to work around this with
  `save!(validate: false)` inline in the test — association cache
  interactions during `save!` make it unreliable in practice. Leave
  `update_attribute` and add a comment if the reason is not obvious from
  context.
- If `update_attribute` is being used to set a past date that fails
  validations, the right fix is a factory **trait** using `to_create {
  |instance| instance.save!(validate: false) }`. Domain states like
  "overdue" belong in the factory, not in each spec. The `homework`
  factory already does this:
  ```ruby
  trait :overdue do
    due_date { 1.day.ago }
    to_create { |instance| instance.save!(validate: false) }
  end
  ```
- Use a **nested factory** (child factory inheriting from the parent)
  when the variant represents a meaningfully distinct object type rather
  than a reusable attribute combination. Traits compose; nested factories
  name a specific thing. Example:
  ```ruby
  factory :homework do
    # base attributes

    factory :overdue_homework do
      due_date { 1.day.ago }
      to_create { |instance| instance.save!(validate: false) }
    end
  end
  ```
  Prefer a trait when the state is likely to be combined with other
  traits (`create(:homework, :overdue, :with_progress)`). Prefer a
  nested factory when the variant is always used as a standalone object
  and combining it with other traits doesn't make sense.

### Rule 6: Replace fragile queries with explicit finders

```ruby
# Before — fragile, relies on implicit side-effects
HomeworkProgress.where(homework: homework, user: student).first.update!(completed: true)

# After — explicit, fails loudly if the record is missing
homework.homework_progresses.find_by!(user: student).update!(completed: true)
```

### Rule 7: Use let vs let! correctly; remove unused let! declarations

`let` is lazy — the block runs the first time the name is referenced.
`let!` is eager — it runs as a before hook before every example.

Use `let!` when the record must exist before the test body runs. Common
reasons include:
- A `before { visit }` loads the page and the record must be present.
- The record is created for its side effects (e.g. triggering a callback
  under test) rather than for a value it returns.

If the record is only referenced inside the `it` block, use `let`.

Don't use `let` + `before { name }` (a "forced reference") as a
stylistic substitute for `let!`. In the common case the two have the
same effect and `let!` is the idiomatic form.

```ruby
# let! needed — homework must exist when the page loads
context "when homework is overdue" do
  let!(:homework) { create(:homework, :overdue, classroom: classroom, topic: topic) }
  before { visit(dashboard_path) }

  it "shows an exclamation icon" do
    expect(page).to have_css("svg.fa-exclamation")
  end
end

# let is sufficient — question only needed after page loads
context "when submitting an answer" do
  let(:question) { create(:question, topic: topic) }

  it "awards points" do
    visit(quiz_path)
    # question referenced here, lazy creation is fine
    click_button question.text
    expect(page).to have_content("Correct!")
  end
end
```

**Exception — record must be created after another `before` block.**
`let!` registers a hook in the order it's declared within the example
group. If a dependent record needs to be created *after* some other
setup — typically because a model callback depends on records created
earlier (e.g. `Homework.after_create` populates `HomeworkProgress` for
currently-enrolled students) — a `let!` declared at the top of the
group will not be ordered after a `before` block declared below it,
and the callback fires against incomplete state.

The right fix is **not** the forced reference. It is to promote the
prerequisite setup to `let!` (or named `let!`s) too, listed in
dependency order:

```ruby
# ❌ Forced reference + ordering comment — sidesteps the real issue
let(:homework) { create(:homework, classroom: classroom, topic: topic) }

before do
  create(:enrollment, user: student, classroom: classroom)
  homework # must be created after enrollment so progress callback fires
  visit(user_path(student))
end

# ✅ Declaration order = semantic order; before block is pure actions
let!(:student_enrollment) { create(:enrollment, user: student, classroom: classroom) }
let!(:homework) { create(:homework, classroom: classroom, topic: topic) }

before do
  visit(user_path(student))
end
```

Name the prerequisite `let!` even when nothing references it by name:
the name documents "this record must exist", and ordered `let!`s remove
the comment a forced reference would otherwise need. If you're writing a
comment to justify a bare reference inside a `before` block, the
structure is wrong — restructure with `let!`s in dependency order instead.

A `let!` that is never referenced in any test body or other `let` is
creating a record for every example in that context needlessly. Remove
it. If a test *should* exist to cover that record's behaviour, add a
pending `it` instead.

### Rule 8: Scope let declarations to where they are needed

If a `let` or `let!` is only used in one nested context, move it inside
that context. Top-level `let` declarations should only contain state
shared across multiple contexts.

### Rule 9: Verify ordering tests assert both positions

A test that checks an element is "first" only passes trivially if there
is only one element. Ordering tests must assert at least two positions:

```ruby
# Before — passes even if only one row exists
expect(page).to have_css(".row:first-child[data-id='#{a.id}']")

# After — meaningful ordering assertion
expect(page).to have_css(".row:first-child[data-id='#{a.id}']")
  .and have_css(".row:nth-child(2)[data-id='#{b.id}']")
```

### Rule 10: Redundant Capybara arguments — [system + request]

- `find(:css, selector)` — `:css` is Capybara's default. Use
  `find(selector)`.
- `have_no_content("i.fa-star")` checks for the *text* `"i.fa-star"`,
  not for the CSS element. Use `have_no_css("i.fa-star")`.

### Rule 11: Pair positive and negative assertions across contexts

A negative assertion (`have_no_css`, `have_no_content`, `have_no_link`)
is only trustworthy if a corresponding positive assertion exists
somewhere in the same describe block — and vice versa.

- If a context asserts that element X is **absent**, check that another
  context asserts X is **present**. If no positive counterpart exists,
  the negative could pass vacuously (the feature may be broken and never
  render X at all).
- If a context asserts that element X is **present**, check that another
  context asserts X is **absent** under the appropriate condition. If no
  negative counterpart exists, the test doesn't verify the element is
  correctly suppressed.

When a counterpart is missing, add a pending `it` in the appropriate
context to flag the gap rather than leaving the coverage asymmetry
silent:

```ruby
context "when homework is overdue" do
  it "shows an exclamation icon" do ... end
end

context "when homework is not overdue" do
  it "does not show an exclamation icon" # pending — counterpart missing
end
```

Do not invent the implementation of the missing test — leave it pending
so the developer can fill in the correct setup. Only add the pending
example if no counterpart exists anywhere in the file; don't flag
symmetry that is already covered by a differently-named context.

### Rule 12: Remove sleep calls and inflated `wait:` arguments — [system]

`sleep` in a system spec is always wrong. Capybara's matchers
(`have_css`, `have_text`, `find`, etc.) already wait up to
`Capybara.default_max_wait_time` for the condition to become true.
Remove any `sleep` and rely on the Capybara matcher to wait:

```ruby
# Before
click_button "Submit"
sleep 1
expect(page).to have_css(".success-banner")

# After — Capybara waits automatically
click_button "Submit"
expect(page).to have_css(".success-banner")
```

A bare `find` whose result is discarded is a hand-rolled wait of the
same shape; delete it and let the next matcher wait.

**When the next step is a server-side push, keep the wait.** If the
example goes on to broadcast over ActionCable, send a Turbo Stream from
a job, or otherwise push to a page that must already be subscribed, no
later matcher can retry a message sent before the subscription existed.
Assert the observable precondition in the `before` block — the
connected marker (`have_css("#connected")`) and the row the push will
change — with a one-line comment naming what it guards.

**A negative assertion straight after an asynchronous trigger checks
nothing.** `have_no_css` is satisfied the instant it runs, before the
broadcast, stream or fetch has landed, so "does not update" passes
whether or not the page would have updated. Send a second trigger on
the same stream that *should* change the page, wait for its positive,
then assert the negative. The Redis and PostgreSQL adapters deliver a
stream's messages in order; the test adapter hands each delivery to a
thread pool, so there the order holds in practice — the second
broadcast's own queries give the first a head start of milliseconds —
not by guarantee.

```ruby
# Before — passes before the broadcast arrives
Leaderboard::BroadcastLeaderboardPoint.new(other_topic, other_student).call
expect(page).to have_no_css("tr#row-#{other_student.id}")

# After — the honoured broadcast proves the ignored one has been delivered
Leaderboard::BroadcastLeaderboardPoint.new(other_topic, other_student).call
Leaderboard::BroadcastLeaderboardPoint.new(topic, student).call
expect(page).to have_css("tr#row-#{student.id}.score-changed")
  .and have_no_css("tr#row-#{other_student.id}")
```

A `wait:` argument longer than the default (`have_css(".x", wait: 6)`)
is the same shape of smell. A Capybara matcher is already in play, but
the default wait isn't enough — usually because the work the assertion
is *really* waiting on isn't a UI update at all. It's a background job
running, an email being sent, or a callback that never surfaces in the
page. The fix isn't a longer wait; it's moving the assertion to a layer
where the work is synchronous (see Rule 16). Route by what the assertion
verifies — these are not interchangeable: the mail's content (recipient,
subject, body) belongs in a mailer spec (assert on the returned
`Mail::Message`: `mail.to` / `mail.subject` / `mail.body`); the job's
effect belongs in a job spec (`perform_now`); *that the action
triggers* the mail/job belongs in a request spec (`have_enqueued_mail` /
`have_enqueued_job`). Leave the user-facing flash assertion in the system
spec if it exists; move each email/job assertion to whichever of those
fits — `spec/mailers/` and `spec/jobs/` both exist here, and adding a
file to either is near-zero friction — rather than downgrading a
content/behaviour assertion to an enqueue check to dodge a new layer.

If a `sleep` or `wait:` was masking a timing problem that no Capybara
matcher can wait for, flag it with a comment rather than leaving the
workaround in place.

### Rule 13: Don't use all/first for element lookup — [system + request]

`page.all(".thing")` and `page.all(".thing").first` return immediately
without Capybara's retry logic. This makes tests brittle against async
page updates.

Replace with a waiting finder or a CSS positional selector:

```ruby
# Before — no waiting, can fail on async updates
page.all(".leaderboard-row").first

# After — Capybara waits for the element
find(".leaderboard-row:first-child")

# Or scope with within when the selector is ambiguous
within(".leaderboard") { find(".row") }
```

When asserting on count, use `have_css` with `count:` rather than
calling `.count` on `all(...)`:

```ruby
# Before — no waiting, count checked immediately
expect(page.all(".item").count).to eq(3)

# After — Capybara waits until the count matches
expect(page).to have_css(".item", count: 3)
```

On a `fields_for` table, `tr:nth-child(2)` and `tr:last-child` miss: the
hidden `id` inputs sit in the `tbody` beside the rows, so use
`tr:nth-of-type(2)` / `tr:last-of-type` instead.

### Rule 14: Assert browser observations, not database state — [system]

**This rule applies to system specs only.** Model, request, and unit
specs should freely assert on model/DB state — that is their purpose.

System specs verify the system from the user's perspective. After an
action, assert what the user sees — not what ended up in the database.
A DB assertion can pass even when the UI is broken or fails to render
the result.

```ruby
# Before — tests the database, not the user experience
click_button "Submit"
expect(HomeworkProgress.find_by(user: student, homework: homework).completed).to be true

# After — tests what the user actually sees
click_button "Submit"
expect(page).to have_content("Homework complete")
```

Legitimate exceptions — where a DB or model assertion is acceptable:

- **Background jobs** with no synchronous UI side effect (use
  `perform_enqueued_jobs` and then check the DB, or assert the job was
  enqueued).
- **Email delivery** — check `ActionMailer::Base.deliveries` since the
  sent email has no browser representation.
- **State with no visible representation** — if the feature genuinely
  stores something with no UI feedback, note why the DB assertion is
  necessary with a comment.

In all other cases, find the observable browser outcome and assert
that instead.

### Rule 15: Use the most specific matcher

Choose the matcher that most precisely expresses the intent. Vague
matchers produce vague failure messages. Quick reference:

| Instead of | Use |
|---|---|
| `eq(true)` / `eq(false)` / `eq(nil)` | `be true` / `be false` / `be_nil` |
| `expect(record.valid?).to be true` | `expect(record).to be_valid` — every `?` method has a `be_` matcher |
| `eq([])`, `.count).to eq(0)` | `be_empty`; `have_css(sel, count: 0)` |
| `include(...)` when extra items should fail | `contain_exactly(...)` |
| `match_array([...])` | `contain_exactly(...)` |
| chained `eq` on one object's attributes | one `have_attributes(...)` |
| three `it`s re-running one setup to check one property each | one `it` with `contain_exactly(have_attributes(...), ...)` |
| `eq` on a float or decimal | `be_within(0.01).of(x)` |
| asserting on `.first`, or `each { expect(...) }` | `all(matcher)` |
| bare `raise_error` | `raise_error(SpecificError, /message/)` |
| `have_text(".css-selector")`, `have_css("Visible text")` | `have_css(".css-selector")`, `have_text("Visible text")` |
| `change { }.by(n)` when both boundary values matter | `change { }.from(a).to(b)` |

Read `references/matchers.md` for the full catalogue with before/after
examples, including when `be_truthy` is correct, `include` versus
`contain_exactly`, and `by` versus `from/to`.

### Rule 16: Move each assertion to the cheapest layer that still tests it correctly — [system → cheapest correct layer]

System specs that boot a real browser — the `:js`-tagged ones (see
*Project profile* — system-spec driver) — are the most expensive flavour
in the suite. Spend them only on coverage that actually requires the
browser. If an assertion can be made in a request, policy, mailer, job,
model or jest spec, move it there. (Non-`:js` system specs run at rack level;
Rule 16b governs when to relocate those.)

| Assertion | Belongs in |
|---|---|
| Pundit policy decision (this role can/can't do X) | `spec/policies/<name>_policy_spec.rb` |
| Navbar / view conditional based on role | `spec/requests/...` asserting on `Capybara.string(response.body)` |
| Link `href` / route presence | `spec/requests/...` asserting on `Capybara.string(response.body)` |
| Mailer recipient, subject, body | `spec/mailers/<name>_mailer_spec.rb` |
| Mailer or job is enqueued by a controller action | `spec/requests/...` with `have_enqueued_mail` / `have_enqueued_job` |
| Background job behaviour | `spec/jobs/<name>_job_spec.rb` |
| Model validations, scopes, callbacks | `spec/models/<name>_spec.rb` |
| Pure client-side logic: sorting, windowing, filtering, formatting, a guard or branch in a Stimulus controller or Alpine component | `spec/javascript/<path>.test.js` (jest; see *Project profile* — JS test runner) |
| The JSON an XHR-filled page loads: keys, entries, filter options | `spec/requests/...` asserting on `response.parsed_body` |
| Browser/JS-dependent interaction, or the form-wiring smoke (Rule 16b) | `spec/system/...` (`:js` only when a real browser is needed) |

Note: the table routes by *correctness*, not convenience — each assertion
goes where it is actually tested (mail content → mailer spec; "the action
triggers it" → request-spec enqueue check; job behaviour → job spec). If
the correct home is a layer with no spec for that class yet, create the
file — near-zero friction in rspec-rails (no config; the spec type is
inferred from the directory), never a reason to route the assertion
elsewhere. The only thing that keeps an assertion *out* of a mailer/job
spec is Rule 17 — a static, no-signal template isn't worth its own spec.

What stays in system specs: end-to-end user flows that exercise JS,
multi-step interactions, and assertions about what the user actually
sees rendered.

**Client-side logic moves to jest in the same pass, not a later one.**
When a browser example exercises a branch of a Stimulus controller or
Alpine component that a jest test can reach with author-written state —
a sort, a ten-row window, a filter predicate, a star or icon formatter,
a `received` guard — the jest test is the cheapest correct layer, and it
is written under the same three steps as any other relocation: write it,
break the function and watch it fail, then delete the browser example.
Flagging it for a later pass is not a relocation: the browser example
either stays at full cost or goes on a promise, and the promise is the
suite-level hole Rule 16a warns about. The browser keeps one example
per component proving the wiring the jest test cannot, and it walks
every wiring path the component has: the load (fetch → JSON → rendered
rows) and then the push (cable → `received` → DOM) in one example,
which is how Rule 16a's one smoke per mechanism is met without a
second boot. Annotate it with the jest file that holds the branches.
"Mocking `alpinejs` leaves the
rendered ranks unproven" is not a reason to keep the branches in the
browser: the wiring smoke proves rendering once; the branches need
proving per branch, and jest is where that is cheap. If importing the
module in jest throws — a module-level side effect jsdom cannot host —
keep the browser example and record the error in its annotation.

When relocating coverage:

1. Write the equivalent assertion in the cheapest correct layer first.
2. Verify the new spec runs and fails *for the right reason* if you
   temporarily break the application code under test; revert the break
   afterwards.
3. Then delete the system-spec assertion (or the whole `it` block, or
   the whole file if everything in it moved).

Text a browser matched may have come from CSS: `text-transform:
uppercase` turns "Create Lessons" into "CREATE LESSONS" only in Chrome.
At rack level, and through `Capybara.string`, the source text is what
renders, so re-case the relocated assertion or match the element
instead.

A common pattern: a system spec contains one positive happy-path test
plus several negative authorisation tests ("role X doesn't see button
Y"). The negative tests are pure Pundit decisions reflected in the
view. Keep the happy path as a system spec; move every negative to a
policy spec. Boots-per-suite drops sharply with no loss of signal.

### Rule 16a: Don't keep N browser tests for one shared mechanism — [system]

When several `:js` system specs differ only in their resource but
exercise the *same* generic framework wiring (e.g. a Turbo
`turbo_confirm` delete across several resources), that wiring needs
proving once — not once per resource.

- Move each spec's server-side assertions (record destroyed, flash,
  redirect) down to the resource's request spec (Rule 16).
- Keep exactly **one** representative `:js` spec **per distinct
  mechanism** as a smoke test for that wiring; delete the rest. That is
  one *per mechanism*, not one per suite — a suite with a `turbo_confirm`
  delete dialog *and* a Stimulus `nested-fields` row insert keeps one
  smoke for each, but only one of each. A mechanism is one client-side
  code path: two actions of the same Stimulus controller count
  separately when they run different code (a client-side row insert
  versus a programmatic submit with `_destroy`).
- Don't keep all of them — identical browser boots are the
  boots-per-suite waste Rule 16 exists to remove; the suite gets no
  faster.
- Don't delete all of them — request specs don't exercise the confirm
  dialog / remote behaviour, so one smoke test must remain.
- **Map examples to branches before consolidating.** List the
  mechanism's branches from its code, then put each existing example
  against the branch its data actually reaches — not the branch its
  description names. Examples sharing a branch collapse to one; a branch
  a description names but no example's data reaches gets one now, in
  the cheapest layer (jest for client code). Writing that example is
  relocation, not invention: the description already claimed the branch
  ("mid-table", "near the bottom"); only the data missed it. "A refactor
  relocates, it doesn't invent" and "flag, don't add" do not apply to a
  branch an existing description names. A branch no description names
  is a gap to flag, not to fill.

Annotate the retained smoke test with a comment pointing to where the
per-resource coverage now lives, so a later pass doesn't re-evaluate it.

### Rule 16b: Split a non-`:js` form spec — relocate state, keep wiring coverage only where it's at risk — [system]

**A non-`:js` system spec does not boot a browser.** `spec/rails_helper.rb`
runs system specs under `driven_by :rack_test` and switches to Cuprite
only for `:js`. So Rule 16's "expensive browser boot" is *not* a reason
to relocate a non-`:js` spec — it already runs at rack level, barely
above a request spec. Its *state* assertions still move down under step
1 below; what this rule protects is the wiring smoke.

**Every system spec currently carries `:js`, so first ask whether the
tag is earned.** A form spec whose steps are all `fill_in`, `select`,
`check`, `attach_file` and `click_button` on server-rendered pages drops
the tag and runs under rack_test; only then apply the split below.
Judge the tag at the level where it is unearned: drop it from the file
and re-tag only the describe blocks or examples whose steps need a
browser, so a file that mixes both ends up with a bare top-level
`describe` and `:js` on the JS-dependent groups. If every surviving
group needs a browser, the tag goes back on the file. A
genuinely JS-dependent step keeps the tag and is out of scope here: a
Stimulus controller, a Flatpickr date field, Trix rich text, a
`turbo_confirm` dialog, or a Turbo-driven form (`data: { turbo: true }`)
whose response is a Turbo Stream. Plain `attach_file` is not one of
those — it works under rack_test.

What such a create/edit spec *uniquely* exercises is the **form-wiring
chain**: the rendered field labels → the params the form posts → the route
it posts to → the controller's strong-params. A request spec cannot
reproduce this, because its params are **author-written**. Posting
`homework: {classroom_id: classroom.id, topic_id: topic.id}` and then
asserting `homework.classroom` proves only that the controller honours
params *you* supplied — not that the real form renders a `classroom_id`
select posting to that action. Rename the field, drop it from `permit`,
or retarget the form, and the request spec stays green while the page
breaks. (`have_field` in the request spec doesn't close this — that's
Rule 17 padding, and it still proves neither the route nor the permit.)

So neither delete-by-default nor keep-by-default. **Split the spec:**

1. **Move the state assertions to the request spec regardless** —
   `change(Model, :count)`, persisted attributes, flash, redirect. They are
   cheaper and more direct there (Rule 14), and the invalid-submit
   example — existing, or written under Rule 17 when the action has
   none — already renders the template, so add no form-render padding
   (Rule 17).
2. **Decide the system spec's fate by one observable predicate: does the
   form drive an association or choice input?** — a `select` of an
   association or enum mapping to a `*_id` or `role` param, or nested
   `answers_attributes` rows. A boolean checkbox or a text field is a scalar,
   whatever widget renders it.
   - **Yes → keep exactly one trimmed rack_test fill-and-submit happy
     path** as the wiring smoke: fill the real form, assert the visible
     success signal — the flash, or the created record on the page it
     redirects to when the action sets no flash — nothing more (the
     count / attribute / negative assertions now live in the request
     spec). Still rack_test — not a `:js` boot.
     Annotate it with a comment pointing to the request spec that now owns
     the state assertions.
   - **No — only scalar `fill_in` fields on a RESTful route → relocate and
     delete.** Author-written params plus the invalid-submit
     example — existing, or written under Rule 17 — already pin
     everything that can break.

"It's a genuine end-to-end flow" / "keep the happy path" does **not**, by
itself, justify keeping the spec, and never justifies a `:js` boot — only a
named association/choice input the request layer can't pin does.

### Rule 17: Remove tests with no signal beyond Rails defaults

A test that asserts only that `= @x` rendered, that a link points
to the route it was generated from, or that an enum predicate returns
the documented value is testing the framework, not the application.
Such tests cannot fail in any way the application could plausibly
break.

```ruby
# Before — passes for any code that doesn't 500
it "shows the school name" do
  visit(school_path(school))
  expect(page).to have_content(school.name)
end
```

Delete these. If you cannot articulate a regression the test would
catch — beyond "the page errors out", which is already covered by every
other test that visits the page — the test is rot.

**A vacuous original is relocated by its description.** An example that
cannot fail as written — an `exact_text:` that is not a String (Rule
21), a value that coincides with the one it is meant to exclude, a
negative asserted before an asynchronous trigger lands (Rule 12) — has
never tested anything, so what it *names* is the coverage to relocate.
Give it data that discriminates, write it in the cheapest correct
layer, and run it unmarked. If it passes, it is done. If it fails,
read the message before marking anything: a known-failure marker
passes on any failure, so a broken mock or selector would hide behind
it, and a failure anywhere but the description's own assertion is the
new example's bug to fix first. When that assertion is what fails,
because the application does not do what the description says, keep
the example as a known failure — `pending "<what the app does
instead>, see #N"` at the top of the block in RSpec, `test.failing`
with the same comment in jest — and report the defect with a drafted
issue. A known failure still runs its block, so the example fails the
run the day the fix lands and retires itself; `xit`, `skip` and
`test.todo` never run and never flip, so they are not substitutes.
Never rewrite the assertion to match the wrong behaviour. The marker
cites the issue (Rule 18b), and a comment naming the defect is not a
ticket: ask for the number at Step 3, or for leave to open the issue.
If the pass ends without one, delete the example and paste it verbatim
into the report, so opening the issue and restoring it is one step.

Borderline cases worth keeping: a single assertion-per-role that the
page renders at all, as a smoke check, when the page is non-trivial
and not already covered by a request spec. Trivial views don't need
smoke tests; the policy or request spec already covers "the action
returns 200 for this role".

**This applies at the request layer too — don't *add* form-render
padding.** After a system→request migration the tempting "new coverage"
is `it "renders the new/edit form" do get …;
expect(Capybara.string(response.body)).to have_css("form") end`. Don't
write it. The `re-renders with errors when invalid` example for that
action already renders the same `new`/`edit` template through a real
branch, so a bare GET-renders-form test catches no regression it doesn't.
Asserting a named field (`have_field("homework[due_date]")`) is the same
Rails-default presence — still padding. The "borderline keep" allowance
above does **not** license these: a `new`/`edit` action always has an
invalid-submit branch to test, and that example is the coverage to
write. Once it exists the page is covered by a request spec and the
allowance no longer applies. That example asserts that nothing persisted and
that the re-rendered form carries the error message; assert
`:unprocessable_content` only where the action sets it.

### Rule 18: Delete stale pending tests

A pending `it` (a description string with no body) earns its keep only
as a near-term placeholder for a Rule 11 counterpart inside the same
describe block. Two failure modes to delete:

1. **Pending counterparts pointing at other files.** If the "missing"
   counterpart is actually covered by a different file under a
   different role or feature, the pending implies coverage gaps inside
   this file that do not exist. It misleads readers. Delete it.
2. **Files that are nothing but pendings.** A spec file with three
   `it "TBD"` strings, no setup, no factories, no ticket reference, is
   a TODO list pretending to be tests. Delete the file. An empty
   `describe` with no examples at all is the same rot. If the work is
   tracked elsewhere, that's where the TODO belongs.

A pending is acceptable when it has either (a) a clear counterpart in
the same describe block (Rule 11), or (b) a comment linking to a
specific ticket with a concrete reason it is deferred. Anything else is
rot.

A `pending` with a body is a different thing from the bodiless
placeholder above: RSpec runs the block and fails the run when it
passes, so it pins a known defect until the fix retires it (Rule 17).
It needs the ticket of (b), and its reason string names what the
application does instead.

### Rule 19: Use `shared_examples` for repetition across describe blocks

Rule 15's "consolidate fragmented state assertions" addresses
repetition *within* an `it` block. This rule covers repetition *across*
describe blocks — three or more near-identical describes that differ
only in a parameter (role, type, table id, subject area).

```ruby
# Before — three describes, all the same shape with one variable
describe "school admin role" do
  before { visit(manage_roles_users_path(school: teacher.school)) }

  it "adds the role" do
    select "school_admin", from: "user[role]"
    click_button "Add Role"
    within("#school_admin-table") do
      expect(page).to have_content("#{teacher.forename} #{teacher.surname}")
    end
  end
end

describe "question author role" do
  # same shape, with a subject select and #question_author-table
end

describe "lesson author role" do
  # same shape, with a subject select and #lesson_author-table
end

# After — one shared_examples, parameterised include_examples calls
shared_examples "a manageable role" do |role_name:, table_id:, requires_subject:|
  before { visit(manage_roles_users_path(school: teacher.school)) }

  it "adds the role to the user" do
    select quiz_subject.name, from: "user[subject]" if requires_subject
    select role_name, from: "user[role]"
    click_button "Add Role"
    within(table_id) do
      expect(page).to have_content("#{teacher.forename} #{teacher.surname}")
    end
  end
end

describe "school admin role" do
  include_examples "a manageable role",
    role_name: "school_admin", table_id: "#school_admin-table", requires_subject: false
end

describe "question author role" do
  include_examples "a manageable role",
    role_name: "question_author", table_id: "#question_author-table", requires_subject: true
end

describe "lesson author role" do
  include_examples "a manageable role",
    role_name: "lesson_author", table_id: "#lesson_author-table", requires_subject: true
end
```

Apply when three or more describe blocks share the same scaffolding and
differ only in parameters. With two, the duplication is below the
abstraction tax — leave them inline. Two caveats:

- **`let!` inside `shared_examples` may need to be eager.** A record
  that was lazy at the describe level (e.g., a `let` provided by a
  shared context) may not exist when the shared `before { visit }`
  runs. Promote to `let!` inside the shared examples block, or
  reference the let in the `before` block to force it.
- **Conditional `let!`** declarations (`let!(:x) { ... } if condition`)
  inside `shared_examples` are evaluated at include time — the
  condition can read kwargs. Useful when only some parameterisations
  need a record.

### Rule 20: Don't shadow shared-context `let`s with same-named local `let`s

If a spec pulls in a shared context that defines named records — `with
default_creates` here (*Project profile*), or one included via
`include_context` — and then declares a `let` with the same name (e.g.
`let(:student) { create(:student, school: school) }`), the local `let`
silently shadows the shared one. Future changes to the shared context
do not propagate; readers must track which `student` is which.

Two acceptable resolutions:

1. **Drop the local `let`** and rely on the shared one if its
   definition suits. Often the shadow is unintentional and the shared
   value works.
2. **Rename locally** when you genuinely need a different record:
   `let(:impersonated_student) { create(:student, school: school) }`.
   Don't reuse the shared name.

A third resolution — extending the shared context itself — is fine when
the shadowed `let` represents a state the shared context should have
provided in the first place. Outside that scope, prefer renaming.

A shared-context `let` that must exist before a `before { visit }` is
not a shadowing case: `let!(:topic) { super() }` keeps the shared
definition and only makes it eager, which is what Rule 7 asks for
instead of a forced reference. `spec/system/leaderboard/user_selects_a_leaderboard_spec.rb`
uses this form.

To decide whether a shared-context `let` is worth keeping at all, run
the shadow-rate audit in `references/shadow-audit.md`.

### Rule 21: Make presence/absence assertions collision-proof — [system + request]

`have_text` / `have_no_text` / `have_link` / `have_no_link` /
`have_no_content` match by **substring**. So a negative assertion is only
reliable if the value it asserts absent can never appear inside the
page's legitimately-rendered content — and a positive assertion can match
the wrong element for the same reason. Any value the test does not fully
control, or that can overlap another rendered value, is a latent flake.

This bites hardest in "shows this entity's X, not other entities' X"
specs, where one record is rendered and a sibling is asserted absent:

```ruby
# Flaky — topic names are a bare FFaker::Lorem.word, so two topics can
# draw the same word, or one that contains the other ("ut" inside "aut"),
# and have_no_text then matches the legitimately-rendered topic.name.
let!(:topic)       { create(:topic, subject: quiz_subject) }
let!(:other_topic) { create(:topic) }

it "lists this subject's topics and not other subjects' topics" do
  expect(Capybara.string(response.body)).to have_text(topic.name)
    .and have_no_text(other_topic.name)
end
```

Where the colliding value comes from — most common first:

- **FFaker dictionaries.** Collision rate tracks the source size:
  `FFaker::Lorem.word` and `FFaker::Color.name` draw from small finite
  lists and coincide often; `FFaker::Name` and long `FFaker::Lorem`
  sentences far less often but never zero. Distinct strings are not
  enough: "Psychology" is still a substring of "Applied Science
  (Psychology)".
- **Sequence values.** The `subject` factory's `"#{FFaker::Lorem.word}
  #{n}"` makes `"amet 1"` a substring of `"amet 10"` whenever the two
  records draw the same word. Safe only when the two records are created
  consecutively, so the higher sibling number can't be a digit-prefix of
  the lower.
- **Fixed catalogs.** Safe only when no entry is a substring of another.
- **Any computed or otherwise test-uncontrolled value** — even a
  hardcoded literal, if it happens to be a substring of other content the
  page renders.

Random ordering and per-seed variation surface these intermittently —
"passes most of the time" is the signature, so the bug survives casual
local runs and only fails in CI.

Two fixes:

1. **Pin the records to explicit, non-colliding literal values** — where
   neither is a substring of the other, and neither appears elsewhere on
   the page — for the attribute under assertion:
   ```ruby
   let!(:topic)       { create(:topic, subject: quiz_subject, name: "Fractions") }
   let!(:other_topic) { create(:topic, name: "Photosynthesis") }
   ```

2. **Match on a uniquely-identifying attribute** instead of free text — a
   `href`, `dom_id`, or id-scoped selector the sibling cannot share:
   ```ruby
   # was: have_no_link(other_topic.name)
   expect(page).to have_no_link(other_topic.name, href: topic_path(other_topic))
   # or
   expect(page).to have_no_css("##{dom_id(other_topic)}")
   ```

**`exact_text:` filters only when given a String or Regexp.**
Capybara's `matches_exact_text_filter?` is `case exact_text when String,
Regexp ... else true end`, so `have_css("td", exact_text: record.score)`
with an Integer applies no filter and passes for any `td`; the same
holds for `nil`. Pass `.to_s` (`exact_text: "530"`), and scope the
selector to the cell (`td#score-#{id}`) so a position column cannot
satisfy it. Treat every non-String value Step 1 listed as an assertion
that has never run. `text:` converts its value with `to_s` and matches
by substring, so `text: 5` is satisfied by "15" or a position cell —
the collision case below, not a no-op.

When you see a presence/absence assertion on `record.attr`, ask whether
that value is fully controlled and collision-proof; if not, give the
record an explicit literal or assert on an id/href the sibling can't
share. This complements Rule 11 — that rule checks *whether* a negative
assertion has a positive counterpart; this one checks whether its *value*
is reliable.

### Rule 22: Instantiate at the cheapest method that still tests the behaviour correctly

Mirror Rule 16's "cheapest correct layer" at the object level. Cheapest
first: **`build_stubbed`** (in-memory, stubbed id, `persisted?` true, no DB
write, no callbacks) for assertions reading only attributes/in-memory
logic; **`build`** (unsaved) when you need an unsaved instance, e.g.
validity checks; **`create`** (inserts the row, runs save callbacks) only
when the test queries the DB (scopes, `find`/`where`, `reload`), depends on
a create/save callback, or the controller reads the DB. Don't `create` by
reflex — `with default_creates` already inserts a school, classroom, and
four users for every tagged example.

---

## Step 3: Present, apply, and verify changes

For each file:

1. List all violations found, grouped by rule.
2. Show the proposed changes (before/after for non-trivial edits).
3. Apply the changes.
4. If a factory change is needed (new trait or nested factory),
   update the factory file.
5. **Run the refactored file before moving to the next one:**
   `NO_COVERAGE=1 bundle exec rspec <path>`. Several refactors only
   surface as failures when the file runs — `let`/`let!` changes inside
   a fresh `shared_examples` block, removing inflated `wait:` args,
   dropping a `:js` tag, or replacing `update_attribute` with `update!`.
   Don't stack changes across files unverified; green the file you just
   touched before opening the next one. A `Ferrum::PendingConnectionsError` on
   the first browser example of a run is pack compilation on first boot,
   not a spec failure; rerun before acting on it.
6. When applying Rule 16, also run the new spec you created in the
   cheapest correct layer — `pnpm test:js <file>` for a jest file. The
   whole point is that the moved assertion still holds — confirm it
   does.

### Scope

In-scope changes:

- Edits to the spec file under refactor.
- Adding a trait or nested factory in `spec/factories/` (Rule 5).
- Adding a **new spec file in another layer** — `spec/policies/`,
  `spec/requests/`, `spec/mailers/`, `spec/jobs/`, `spec/models/`,
  `spec/javascript/` (jest) — to host coverage moved out of a system spec
  under Rule 16. **When
  refactoring**, that new file should cover *only* what was moved: a
  refactor relocates coverage, it doesn't invent it. (Writing a brand-new
  spec from scratch is a *different* task — see *Authoring a new spec*
  near the top — and is fully in scope there.)
- Extracting a `shared_examples` block (Rule 19), inline in the spec
  file or in `spec/support/`.
- Pending examples added under Rule 11 — a description with no body —
  in any file the pass touches. They flag a gap; they invent nothing.
- A known-failure example under Rule 17 — `pending` or `test.failing`
  against an issue — in the cheapest correct layer for the behaviour
  its description names.
- The invalid-submit example Rule 17 calls for when a `new`/`edit`
  action has none: it is the request-layer home of coverage the system
  spec used to carry, not new coverage.

Pre-existing examples in a relocation target stay as they are; running
the skill on that file is a separate invocation.

Out of scope:

- Application code: models, controllers, services, views, mailers,
  jobs, policies. If a refactor reveals an application bug, flag it to
  the user; don't fix it under this skill.
- Factory changes beyond traits and nested factories.
- Helpers and shared contexts other than the `shared_examples` Rule 19
  creates.
- Stylistic renames or helper extraction not driven by a rule above.

### Suite-level check (run once, after all files)

Rule 16a is a **cross-file invariant the per-file pass cannot enforce**:
each file, seen alone, either keeps its own confirm smoke (→ you end with
one per resource) or assumes another file keeps the representative (→ you
end with none — a whole-suite hole no single diff reveals). Reconcile it
in one pass after the per-file work:

```bash
git grep -l 'accept_confirm\|accept_alert' spec/system
```

This must return **exactly one survivor per distinct confirm mechanism**
(here the `turbo_confirm` dialog is the only one, whichever action it
guards). **Empty** = the
pass deleted the last representative — restore one trimmed `:js` smoke
(Rule 16a). **Several for the same mechanism** = consolidate to one,
pushing the rest's server-side assertions down to request specs.

When the invocation covered a single file, list the survivors and stop:
consolidating the other files is a separate invocation over those files,
not a side effect of this one. The file under refactor keeps its own
smoke, annotated per Rule 16a, so the later consolidation pass has a
marked survivor to choose between; deleting it on the assumption that
another file keeps one is the whole-suite hole described above.
