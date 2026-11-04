# The timetable

The base layer of the [schedule](README.md), `Layers::Timetable`: every
zone repeats a week of programs, each program a list of times at which
a preset starts.

- [Bands](#bands)
- [Strategies](#strategies)
- [Presets](#presets)
- [Programs](#programs)
- [The week](#the-week)
- [How a time is resolved](#how-a-time-is-resolved)
- [The layer](#the-layer)

## Bands

A band (`Setpoint`) says when to act, rather than giving a single
target: heat while the room is below `heat`, cool while it is above
`cool`, do nothing in between.

| `Setpoint.new`          | `to_s`         | Use                 |
| :---------------------- | :------------- | :------------------ |
| `heat: 20, cool: 26`    | `+20.0..+26.0` | radiator and aircon |
| `heat: 7`               | `+7.0..`       | frost protection    |
| `cool: 27`              | `..+27.0`      | cooling only        |
| (nothing)               | `off`          | nothing at all      |

Values are rounded to the tenth; anything that is no finite number
(`"abc"`, infinity, NaN) raises `Error`. The two sides must be at
least `DEADBAND` (1 °C) apart, so that a radiator and an aircon in one
zone never fight; closer ones raise `Error`:

```ruby
Setpoint.new(heat: 24, cool: 24.5)
# Error: heat 24.0 must be at least 1.0 below cool 24.5
```

## Strategies

How the devices share the work of holding a band, one of `STRATEGIES`:

| Strategy    | Intent                                      |
| :---------- | :------------------------------------------ |
| `:comfort`  | steady and even; `DEFAULT_STRATEGY`         |
| `:cheapest` | lowest running cost                         |
| `:quiet`    | as little noise as possible (bedrooms)      |
| `:quick`    | reach the band fast, both devices if needed |

Here a strategy is a label carried through the decision; what it does
to the devices is the planner's. `Schedule.strategy(value)` takes a
String or a Symbol, returns nil for nil or empty (inherit) and raises
`ParseError` for an unknown one. Every value that holds a strategy
(`Preset`, `Transition`, `Zone`) goes through it.

## Presets

A `Preset` is a band, optionally named, with an optional strategy and
description. A preset without a name is anonymous: written inline,
belonging to the one place that uses it (`label` is then its band).

`Preset::SYSTEM` holds the presets the layers fall back on, each also a
constant:

| Constant      | Name          | Band               | Held by                    |
| :------------ | :------------ | :----------------- | :------------------------- |
| `FROST`       | `frost`       | `+7..`             | a zone without a timetable |
| `AWAY`        | `away`        | `+16..+30/cheapest`| an away period             |
| `BOOST`       | `boost`       | `+23..+24/quick`   | a boost                    |
| `BOOST_HEAT`  | `boost-heat`  | `+24../quick`      | a heating boost            |
| `BOOST_COOL`  | `boost-cool`  | `..+22/quick`      | a cooling boost            |
| `OPEN_WINDOW` | `open-window` | `+7..`             | an open window             |

Each layer takes its fallback as an argument (`fallback:`, `default:`,
`defaults:`), so a caller keeping presets passes its own versions; a
store should let these be changed but not deleted.

## Programs

A `Program` is one day: `Transition`s, each a minute after midnight
from which a preset holds, with a strategy overriding the preset's when
given. They are sorted by time, and two at the same minute raise
`Error`. A program without a name is anonymous (`label` is
`(inline)`).

```ruby
work = Program.new(name: "work", transitions: [
    Transition.new(minute: 6 * 60 + 45, preset: comfort),
    Transition.new(minute: 8 * 60 + 30, preset: eco),
    Transition.new(minute: 23 * 60, preset: night, strategy: :quiet)
])
```

[Syntax](syntax.md#programs) reads the same from
`06:45=comfort,08:30=eco,23:00=night/quiet`, preset names coming back as
Strings for the caller to look up.

## The week

A `Timetable` maps weekdays (`days:`, 0 is Sunday as in `Time#wday`)
and special days (`specials:`, by name, such as `"holiday"`) to
programs. A weekday may have none. Special days only run when a
[calendar](calendar.md) gives a date that day. `program_for(kind)` gives
the program of `"sun"`..`"sat"` or of a special day.

## How a time is resolved

`Timetable#at(time)` gives the `Timetable::Entry` in force (the program,
its transition, and the date the program ran on):

1. Take the program of the time's date.
2. Take its last transition at or before the time of day.
3. If there is none yet, take the last transition of the most recent
   earlier day that has one, looking back up to a week. So
   `23:00=night` lasts until the next morning's first transition, and a
   day without a program carries on from the day before.

`Timetable#next_change(time)` is the first transition after the time,
looking ahead up to a week; nil if there is none.

With `work` every day:

```text
        06:45    08:30                   23:00   00:00     06:45
──────────┬────────┬───────────────────────┬───────┼─────────┬────────▸
   night  │comfort │          eco          │      night      │ comfort
Monday                                             Tuesday
```

Both take an optional block, the program of a date, the weekday's by
default; that is how the calendar runs other days.

Times are local wall-clock times in the process's time zone. On the
night clocks go forward, a transition in the missing hour (02:30)
happens at 03:30; on the night they go back, at the first 02:30.

## The layer

`Layers::Timetable.new(fallback: Preset::FROST)` decides from the
zone's timetable: the transition's preset, the transition's strategy
over the preset's, source `timetable:PROGRAM`, `until` the next change.
A zone with no transition within the week before holds the fallback,
source `fallback`, with no `until`.
