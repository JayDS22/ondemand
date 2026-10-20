# #5445 implementation plan — pre-draft, pending Jeff Ohrstrom's design answer

**Status:** Planning only. No production code committed on this branch yet. Flesh out when Jeff responds to the three design questions on the issue.

**Branch:** `feature/auto-wallclock-limit-5445` on `JayDS22/ondemand`.

## Decision table

| Jeff's answer on shape | Jeff's answer on source | Scope | Code change on this branch |
|---|---|---|---|
| (b) reuse `bc_num_hours` | (b1) add `max_time` to `ood_core` QueueInfo first | BC only | 15-20 LOC in `account_cache.rb` + 1 unit test. Companion `ood_core` PR must land first. |
| (b) reuse `bc_num_hours` | (b2) parse `scontrol` in dashboard helper | BC only | ~40 LOC: new helper + `account_cache.rb` call + 1 unit test. Standalone. |
| (a) standalone `auto_wallclock_limit` | n/a | BC + PM | Mirror Harshit's `bc_num_nodes` arc. ~500 LOC across 10 files (new attribute file, factory, controller allowlist, launcher helper, view template, JS entry, unit test, system test). |

## Minimum change sketch for the lazy path (option b2, standalone from `ood_core`)

Files that would change:

1. **`apps/dashboard/app/lib/account_cache.rb#queues`** — extend the `queue_account_data(queue)` merge to add a per-queue `data-max-bc-num-hours-for-auto-queues-<name>` entry when a per-queue max wallclock is known.

2. **New helper**: `apps/dashboard/app/lib/account_cache.rb` additions (private module method) that shells out via `Open3.capture3(scontrol, 'show', 'part', '-o', '-M', cluster.id)`, parses `PartitionName=\S+` and `MaxTime=\S+` tokens, normalizes DD-HH:MM:SS or UNLIMITED into integer hours, Rails.cache-fetches for 4 hours. Error path logs and returns `{}` identical to existing `queues_per_cluster` rescue clause.

3. **`apps/dashboard/test/lib/account_cache_test.rb`** — new unit test. Stub `Open3.capture3` with fixture `test/fixtures/cmd_output/scontrol_show_partitions_oakley.txt` which already contains `MaxTime=7-00:00:00` and `MaxTime=04:00:00` tokens. Assert that `account_cache.queues` tuples carry the expected `data-max-bc-num-hours-for-auto-queues-<name>` entries.

Total: ~40 LOC + 1 test.

**Why the fixture already works**: `apps/dashboard/test/fixtures/cmd_output/scontrol_show_partitions_oakley.txt:1-9` includes real partition lines with `MaxTime=` values. No new fixture needed.

## Minimum change sketch for the clean path (option b1, with `ood_core` companion PR)

Companion `ood_core` PR:

1. **`lib/ood_core/job/queue_info.rb`** — add `attr_reader :max_time`, extend `initialize` to accept `max_time:`.
2. **`lib/ood_core/job/adapters/slurm/batch.rb`** (or wherever `queues` is parsed) — parse `MaxTime=` from `scontrol show part -o`, pass to `QueueInfo.new`.
3. New unit test for the parser.

Then on ondemand side:

1. **`apps/dashboard/app/lib/account_cache.rb#queues`** — extend `queue_account_data(queue)` to include `data-max-bc-num-hours-for-auto-queues-<name>` using `queue.max_time`.
2. **`apps/dashboard/test/lib/account_cache_test.rb`** — unit test; stub `Open3.capture3` with the oakley fixture.

Total ondemand side: ~15 LOC + 1 test. Companion `ood_core` PR separate.

## Standalone attribute sketch (option a)

Mirror Harshit's `bc_num_nodes` arc, documented in prior session memory. Six-file touch pattern:

1. `apps/dashboard/app/lib/smart_attributes/attributes/auto_wallclock_limit.rb` — new attribute class with factory method. Pattern template: `bc_num_hours.rb`.
2. `apps/dashboard/app/lib/smart_attributes.rb` — add `require`.
3. `apps/dashboard/app/controllers/launchers_controller.rb:8-18` — add `:auto_wallclock_limit`, `:auto_wallclock_limit_fixed`, `:auto_wallclock_limit_min`, `:auto_wallclock_limit_max` to `SAVE_LAUNCHER_KEYS`.
4. `apps/dashboard/app/helpers/launchers_helper.rb` — add `auto_wallclock_limit_template` helper method.
5. `apps/dashboard/app/views/launchers/edit.html.erb` — add `<template id="auto_wallclock_limit_template">` block.
6. `apps/dashboard/app/javascript/launcher_edit.js:5-38` — add entry to `newFieldData`.
7. Unit test + system test.

Reference: Harshit's bc_num_nodes PRs #4323, #4327, #4329.

## Verification plan

1. On Jeff's answer, delete this plan and flesh out whichever route he picks.
2. TDD red first: write the failing test (unit test asserting the data attribute is present / asserting the smart attribute's `select_choices` for standalone).
3. Implement.
4. Run `bin/recompile_js test` then `bin/rails test test/lib/smart_attributes/auto_wallclock_limit_test.rb` or `test/lib/account_cache_test.rb` depending on shape.
5. Push to fork, let CI run.
6. Open upstream PR when green.
