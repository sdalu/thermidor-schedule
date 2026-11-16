# thermidor-schedule

What each zone of a house should hold, over time: heat below one
setpoint, cool above another, and how the devices should share the
work. Decisions come from a stack of layers (a weekly timetable, a
calendar, away, manual, boost, open window, guards, a clamp), each passing the
decision below through or replacing it.

It decides only: where the presets, programs and entries are kept, and
what the devices are told, is the caller's. ClimatControl keeps them in
SQLite and plans from the decisions with `thermidor-planner`, the
planner of the same family.

Ruby ≥ 3.4, standard library only.

```ruby
# Gemfile
gem "thermidor-schedule", github: "sdalu/thermidor-schedule"
```

## A zone, a stack, a decision

```ruby
require "thermidor/schedule"

S = Thermidor::Schedule

comfort = S::Preset.new(name: "comfort",
                        setpoint: S::Setpoint.new(heat: 21, cool: 25))
night   = S::Preset.new(name: "night", strategy: :quiet,
                        setpoint: S::Syntax.band("+17..+27"))

workday = S::Program.new(name: "workday", transitions: [
    S::Transition.new(minute: S::Syntax.minute("06:30"), preset: comfort),
    S::Transition.new(minute: S::Syntax.minute("22:30"), preset: night)
])
week = S::Timetable.new(days: (0..6).to_h { [it, workday] })
zone = S::Zone.new(name: "living", timetable: week)

now   = S::Syntax.time("2026-12-24 07:00")
stack = S::Stack.new([
    S::Layers::Timetable.new,
    S::Layers::Calendar.new([]),
    S::Layers::Away.new([]),
    S::Layers::Manual.new([
        S::Layers::Manual::Entry.new(zone: "living", preset: night,
                                     strategy: nil, starts_at: now - 600,
                                     ends_at: now + 3600, mode: :for)
    ]),
    S::Layers::Clamp.new
])

decision = stack.resolve(zone, now)
decision.setpoint.to_s  # => "+17.0..+27.0"
decision.strategy       # => :quiet
decision.source         # => "manual"
decision.until          # => 2026-12-24 08:00 (the manual setting ends)
stack.wake_at(zone, now)
```

`Stack#resolve` gives the decision of the topmost active layer;
`Stack#decisions` gives the decision after each layer, bottom first;
`Stack#wake_at` the earliest change anywhere in the stack, when to look
again.

The example's morning, layer by layer (`━` decides, `─` is hidden
under a layer above, `╌` has nothing in force): the manual setting
holds its night over the timetable's comfort until 08:00, then lets it
through again, with nothing to restore.

```text
        06:00      06:30      06:50           08:00
manual    ╌╌╌╌╌╌╌╌ none ╌╌╌╌╌╌╌╌┬━━━━ night ━━━━┬╌╌ ended ╌╌╌
timetable ━━ night ━━┼━━━━━━━━━━───── comfort ──━━━━━━━━━━━━━
decision  ━━ night ━━┴ comfort ━┴━━━━ night ━━━━┴━ comfort ━━
```

## Concepts

| Term       | Value                                         | Meaning                                                    |
| :--------- | :-------------------------------------------- | :--------------------------------------------------------- |
| band       | `Setpoint`                                    | heat below `heat`, cool above `cool`; nil for never        |
| humidity   | `Humidity`                                    | a band's optional floor and ceiling, in % (no action yet)  |
| strategy   | `:comfort`, `:cheapest`, `:quiet`, `:quick`   | how the devices combine to hold a band                     |
| preset     | `Preset`                                      | a band, optionally named, with an optional strategy        |
| program    | `Program` of `Transition`s                    | one day: minutes after midnight at which a preset starts   |
| timetable  | `Timetable`                                   | a program per weekday (0 is Sunday) and per special day    |
| zone       | `Zone`                                        | a name, an optional strategy, a timetable                  |
| guard      | `Layers::Guard::Entry`                        | a named band read as limits, not a target                  |
| decision   | `Decision`                                    | the band, strategy, source, preset label and next change, who gave the humidity bounds, and which guard bound which side |

A band's two sides are at least the deadband (1 °C) apart, so a
radiator and an air conditioner in the same zone never fight;
`Setpoint.new` refuses closer ones with `Thermidor::Schedule::Error`. A
decision's strategy is always resolved: a transition's, else the
preset's, else the zone's, else the default strategy (`:comfort`).

## Configuration

The house's settings are the process's, set once at boot, before any
value is built:

```ruby
Thermidor::Schedule.configure(strategies: %i[comfort eco boost],
                              default_strategy: :comfort, deadband: 1.5,
                              clamp_limits: 7.0..28.0)
Thermidor::Schedule.config.deadband   # => 1.5
```

| Setting               | Default                         | What it is                                                      |
| :-------------------- | :------------------------------ | :-------------------------------------------------------------- |
| `strategies`          | `STRATEGIES`                    | the strategies a band may be held by                            |
| `default_strategy`    | `DEFAULT_STRATEGY` (`:comfort`) | the one given when none is                                      |
| `deadband`            | `DEADBAND` (1.0 °C)             | the least gap between a band's heat and cool sides              |
| `default_on_time`     | `DEFAULT_ON_TIME` (`true`)      | an unmarked program change wanted reached by its time           |
| `clamp_limits`        | `5.0..30.0`                     | what both setpoints are kept within ([clamp](doc/clamp.md))     |
| `manual_longest`      | 12 hours                        | the longest duration of a manual setting ([manual](doc/manual.md#how-long)) |
| `boost_duration`      | 30 minutes                      | a boost's length when none is asked ([boost](doc/boost.md))     |
| `boost_longest`       | 1 hour                          | the longest duration of a boost                                 |
| `open_window_limit`   | 1 hour                          | a steady window's safety limit when none is asked ([open window](doc/open-window.md)) |
| `open_window_longest` | 2 hours                         | the longest an open window is held                              |
| `auto_away_leave`     | 20 minutes                      | how long everyone is gone before an automatic away ([away](doc/away.md#automatic-away)) |
| `steady_span`, `steady_tolerance`, `steady_change`, `steady_rebound`, `steady_after` | 600 s, 0.2 °C, 2.0 °C, 0.5, 900 s | when an open window's room counts as shut again ([Steady](doc/open-window.md#steady-shut-again)) |

Durations are whole seconds. `Config::DEFAULT` holds the defaults. A
setting left out keeps its value; settings that cannot hold together
(no strategy, one named twice, a default that is none of them, a
negative deadband, a `default_on_time` neither true nor false, limits
holding no band under the deadband, a duration of nothing or over its
kind's longest, a threshold negative or a rebound over 1), or one that
does not exist, are refused with `Error`, changing nothing. A layer
or rule built without its argument (`Clamp.new`, `AutoAway.new`,
`Steady.new`) takes the setting in force then; an argument still says
otherwise for its own. A value checks itself
when built, so one built before a change keeps the old rules. A
strategy outside the configured ones counts as not given when a
decision resolves its strategy. The built-in presets (`Preset.system`)
are built for the settings in force when asked, their bands widened to
the deadband and a strategy not configured left out.

## The layers

Bottom first, as they are usually stacked; each takes the entries it
holds as plain values (`Data`), built by the caller from wherever it
keeps them.

| Layer                | Entries                      | Active                                         | Source                          |
| :------------------- | :--------------------------- | :--------------------------------------------- | :------------------------------ |
| `Layers::Timetable`  | none (the zone's timetable)  | always; `fallback:` (frost) with none in force | `timetable:PROGRAM`, `fallback` |
| `Layers::Calendar`   | `Calendar::Entry`, `fallback:` | on dates that run another kind of day        | `calendar:NAME:KIND`, `timetable:PROGRAM`, `fallback` |
| `Layers::Away`       | `Away::Entry`, `auto_since:` | an away period, by hand or from presence       | `away`, `away:auto`             |
| `Layers::Manual`     | `Manual::Entry`              | a setting made by hand, until its end          | `manual`                        |
| `Layers::Boost`      | `Manual::Entry`              | a short push, `mode` its direction             | `boost`                         |
| `Layers::OpenWindow` | `Manual::Entry`              | a window open, until its end                   | `open-window`                   |
| `Layers::Guard`      | `Guard::Entry`               | always: within the zone's guards               | the decision's below            |
| `Layers::Clamp`      | none                         | always: both sides within `limits:`            | the decision's below            |

A layer is anything answering `apply(zone, now, below)` with a
`Decision`: one of the caller's own fits in the stack as well. It must
depend only on the zone, the moment, the decision below and what it was
built with: a stack keeps the decisions of the last zone and moment
asked (in the same time zone, under the same settings), so `resolve`
then `wake_at` run the layers once. A layer reading
something live (a sensor) reads it when its stack is built.

`Preset.system` gives the presets the layers fall back on (frost, away,
the three boosts, open window); a caller keeping presets should let
those be changed but not deleted.

## Around the layers

- `Syntax`: the text forms of bands (`+20.5..+25`, `+7..`, `..+26`,
  with humidity bounds `+20..+26@..60`; a guard's, `@..65` too), preset references (`comfort/quick`, or `off` for no band), programs
  (`06:30=comfort,22:30=+17..+27/quiet`), days (`mon-fri`, `sat,sun`, a
  special day's name), and in `syntax/time.rb` years, dates, times and
  durations (`2h`, `90m`, `1h30`). Refusals raise `ParseError`.
- `Recurrence`: an iCalendar (RFC 5545) rule for whole days,
  `Recurrence.parse("FREQ=YEARLY;BYMONTH=5;BYDAY=-1MO")`, expanded by
  `#occurrences(first, upto, from: nil)`.
- `Holidays.for(region, year)`: public holidays, `[[Date, name], ...]`,
  for `"fr"`, `"fr-alsace-moselle"` and the regions `Holidays.register`
  adds, Easter computed.
- `AutoAway`: when an automatic away period starts, from statuses
  answering `since` and `close?`, after a `leave:` delay.
- `Steady`: whether an open window has been shut again, from the room's
  readings since it was opened and the last one before.

Times are local wall-clock times, in the process's time zone.

## Development

```bash
bundle install
bundle exec rake     # the tests, then RuboCop
```

GitHub runs the same on every push (`.github/workflows/gate.yml`).

Each layer, its entries and its edges: [doc/](doc/README.md). Why it
is shaped so: [DESIGN.md](DESIGN.md).

## Licence

MIT, see [LICENSE.txt](LICENSE.txt).
