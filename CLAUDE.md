# thermidor-schedule

How it works: README.md, and doc/ per layer. Why it is shaped so: DESIGN.md. What closes a
round: CHECKLIST.md.

Gate: `bundle exec rake`

Ruby style: the `ruby` skill (4-space indentation, double quotes,
`.rubocop.yml` is its rule set).

## Traps

- Releases are the owner's: never create or push a tag, nor move
  `VERSION`, unasked. Say a release is due and which number.
- ClimatControl (~/Repos/ClimatControl, the ClimatControl session's
  repo, never edited from here: tell that session) is the one user, naming
  `Thermidor::Schedule` directly and pinning a commit or a tag, as
  thermidor-planner (~/Repos/thermidor-planner) does in its own
  Gemfile: a renamed constant or a changed value breaks them. Run
  both gates against this tree before either moves its pin; schedule
  changes they need come here, never as a copy in their tree.
- A constant defined inside a Data.define block lands in the enclosing
  module, not the class: reopen the class for constants (Preset,
  Timetable::Entry).
- `Schedule.configure` is process-wide: a test that calls it resets
  it in `teardown` (config_test.rb), or every test after it runs under
  its settings.
- Times are local: a test about daylight saving sets TZ (support.rb's
  `in_zone`), never relies on the machine's.
