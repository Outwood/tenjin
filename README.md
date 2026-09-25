# Tenjin

Tenjin is an online quiz platform for schools. Students answer questions, earn rewards, and compete on leaderboards while teachers manage homework and classrooms.

## Features

- Quizzes that keep students engaged with revision across the curriculum.
- Homework management that reduces teacher workload.
- Sync pupil and class data from the school MIS using Wonde.

## Getting started

```bash
bin/setup
pnpm install
```

`bin/setup` installs gem dependencies, creates the database, and prepares the app to run; `pnpm install` installs the JavaScript dependencies.

Copy `.env.example` to `.env` and fill in the required values (database credentials, AWS keys, Wonde API tokens, OAuth credentials).

Run the Rails server and the Shakapacker watcher together:

```bash
bin/dev
```

Or run them in two terminals:

```bash
bin/rails server
bin/shakapacker-dev-server
```

Background jobs (only needed when exercising async work locally):

```bash
bin/rails jobs:work
```

## Running the tests

```bash
bundle exec rspec        # Ruby
bin/parallel_specs       # Ruby, across cores
pnpm test:js             # JavaScript (Jest)
```

Parallel runs give each worker its own database. Create them once, and reload their schema after a migration:

```bash
bin/rails parallel:create parallel:load_schema
```

`PARALLEL_TEST_PROCESSORS` sets the worker count; the default is one per core, or one per performance core on Apple Silicon. Pass paths or `parallel_rspec` options to `bin/parallel_specs` to run part of the suite.

System specs run against a real Chrome via Cuprite; failure screenshots are saved to `tmp/screenshots/`.

## Linting

```bash
bundle exec standardrb   # Ruby
pnpm lint                # JavaScript
```
