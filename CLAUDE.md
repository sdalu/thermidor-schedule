# thermidor-schedule

How it works: README.md, and doc/ per layer. Why it is shaped so: DESIGN.md. What closes a
round: CHECKLIST.md.

Gate: `bundle exec rake`

Ruby style: the `ruby` skill (4-space indentation, double quotes,
`.rubocop.yml` is its rule set).

## Traps

- ClimatControl (~/Repos/ClimatControl, its own session's repo) is
  the one user, naming `Thermidor::Schedule` directly and pinning a
  tag: a renamed constant or a changed value breaks it. Run its gate
  against this tree before tagging; schedule changes it needs come
  here, never as a copy in its tree.
- A constant defined inside a Data.define block lands in the enclosing
  module, not the class: reopen the class for constants (Preset,
  Timetable::Entry).
- Times are local: a test about daylight saving sets TZ (support.rb's
  `in_zone`), never relies on the machine's.
