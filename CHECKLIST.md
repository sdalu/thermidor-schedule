# Closing a round on thermidor-schedule

## Gates

- [ ] `bundle exec rake` passes: tests, then RuboCop.
- [ ] Does ClimatControl's gate still pass against this tree (its
  Gemfile pointed at the local path for the run)? It is the one user.

## Documents

- [ ] `README.md`: does the example still run, and do the layers' table
  and their sources match the code?
- [ ] `DESIGN.md`: did this round change a reason it gives, or make a
  choice it should record?

## Release

- [ ] Does `Thermidor::Schedule::VERSION` in
  `lib/thermidor/schedule/version.rb` move with this round? It is the
  one place the release number is written. Its user (ClimatControl)
  pins a tag.
