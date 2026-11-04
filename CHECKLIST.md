# Closing a round on thermidor-schedule

## Gates

- [ ] `bundle exec rake` passes: tests, then RuboCop.
- [ ] `gh run list -R sdalu/thermidor-schedule -L 1` shows the pushed
  commit's gate passed on GitHub.
- [ ] Does ClimatControl's gate still pass against this tree (a scratch
  clone of it, its Gemfile pointed at the local path)? It is the one
  user, and pins a commit or a tag.

## Documents

- [ ] `README.md`: does the example still run, and do the layers' table
  and their sources match the code?
- [ ] `doc/`: does each page still say what its layer does, its
  examples' outputs included (run them)?
- [ ] `DESIGN.md`: did this round change a reason it gives, or make a
  choice it should record?

## Release

- [ ] Does `Thermidor::Schedule::VERSION` in
  `lib/thermidor/schedule/version.rb` move with this round? It is the
  one place the release number is written. Its user (ClimatControl)
  pins a tag, which the owner makes: propose the number, do not tag.
