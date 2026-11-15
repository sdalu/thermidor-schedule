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
least the deadband apart (`Schedule.config.deadband`, 1 °C unless
[configured](../README.md#configuration)), so that a radiator and an
aircon in one zone never fight; closer ones raise `Error`:

```ruby
Setpoint.new(heat: 24, cool: 24.5)
# Error: heat 24.0 must be at least 1.0 below cool 24.5
```

A band may also bound the relative humidity, in % (`Humidity`, 0 to
100, to the tenth, the floor below the ceiling). `humidity: nil`, the
default, gives none of its own; `Humidity::NONE` clears those below
([A decision](README.md#a-decision)):

| `Setpoint.new`                                         | `to_s`              |
| :----------------------------------------------------- | :------------------ |
| `heat: 20, cool: 26, humidity: Humidity.new(high: 60)` | `+20.0..+26.0@..60` |
| `humidity: Humidity.new(low: 30, high: 60)`            | `off@30..60`        |
| `heat: 22, humidity: Humidity::NONE`                   | `+22.0..@`          |

`off?` speaks of the temperature sides only: `off@..65` is off, with a
ceiling.

## Strategies

How the devices share the work of holding a band, one of
`Schedule.config.strategies`. Unless
[configured](../README.md#configuration) otherwise, they are:

| Strategy    | Intent                                      |
| :---------- | :------------------------------------------ |
| `:comfort`  | steady and even; the default                |
| `:cheapest` | lowest running cost                         |
| `:quiet`    | as little noise as possible (bedrooms)      |
| `:quick`    | reach the band fast, both devices if needed |

Here a strategy is a label carried through the decision; what it does
to the devices is the planner's. `Schedule.strategy(value)` takes a
String or a Symbol, returns nil for nil or empty (inherit) and raises
`ParseError` for one not configured. Every value that holds a strategy
(`Preset`, `Transition`, `Zone`) goes through it.

## Presets

A `Preset` is a band, optionally named, with an optional strategy and
description. A preset without a name is anonymous: written inline,
belonging to the one place that uses it (`label` is then its band).

`Preset::SYSTEM` holds the presets the layers fall back on, each also a
constant:

| Constant      | Name          | Band                | Held by                      |
| :------------ | :------------ | :------------------ | :--------------------------- |
| `FROST`       | `frost`       | `+7..`              | a zone with nothing in force |
| `AWAY`        | `away`        | `+16..+30/cheapest` | an away period               |
| `BOOST`       | `boost`       | `+23..+24/quick`    | a boost                      |
| `BOOST_HEAT`  | `boost-heat`  | `+24../quick`       | a heating boost              |
| `BOOST_COOL`  | `boost-cool`  | `..+22/quick`       | a cooling boost              |
| `OPEN_WINDOW` | `open-window` | `+7..`              | an open window               |

Each layer takes its fallback as an argument (`fallback:`, `default:`,
`defaults:`), so a caller keeping presets passes its own versions; a
store should let these be changed but not deleted. Their strategies are
the default ones; with others [configured](../README.md#configuration),
a decision takes the zone's strategy or the default instead.

## Programs

A `Program` is one day: `Transition`s, each a minute after midnight
from which a preset holds, with a strategy overriding the preset's when
given. They are sorted by time, and two at the same minute raise
`Error`, as does a minute that is not an Integer from 0 to 1439. A
program without a name is anonymous (`label` is
`(inline)`). `usual` is reserved and names no program.

A transition may also be marked `on_time:`, saying whether its change
is wanted reached by its time (`true`: a caller starts early enough),
or only started then (`false`); nil leaves it to the preset, the caller
keeping that flag. A band written inline has no preset to leave it to,
so it must be marked (`Error` otherwise). The mark travels with the
change: `Resolution#on_time`, and `Decision#on_time` from the timetable
and calendar layers, are those of the transition that decided, through
any keyword, and nil when no program did. The schedule only carries it;
starting early is the caller's.

`06:30=comfort:by` and `06:30=comfort:at` as a caller starting early
might run them (its lead, here 45 minutes, is its own):

```text
       05:00       05:45       06:30       07:15
program  ────────── eco ─────────┬━━━━━━━━━ comfort ━━━━━━━━━
:by      ──── eco ───┼─ warming ─┼━━━━━━━ at comfort ━━━━━━━━
:at      ────────── eco ─────────┴─ warming ─┴━ at comfort ━━
```

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

A transition may hold a keyword (`through:`) instead of a preset,
letting another program decide from then on:

| Keyword    | Who decides                                              |
| :--------- | :------------------------------------------------------- |
| `pass`     | the next program in the date's stack                     |
| `usual`    | the zone's weekday program, skipping the calendars below |
| `fallback` | the fallback preset (the house's: frost)                 |

A keyword holds no preset and takes no strategy (`Error`); the three
words are refused as preset names. In a weekday program, with nothing
below it, `pass` and `usual` mean the fallback too, so one program can
be both a weekday's and a calendar day's. The `usual` keyword is not
the `usual` binding of the next section: the binding makes a whole
special day the weekday's, the keyword hands one stretch of a program
over to it. How a calendar stacks programs is in
[calendar.md](calendar.md#letting-another-program-through).

## The week

A `Timetable` maps weekdays (`days:`, 0 is Sunday as in `Time#wday`)
and special days (`specials:`, by name, such as `"holiday"`) to
programs. A weekday may have none. A weekday key other than an Integer
from 0 to 6 raises `ArgumentError`. Special days only run when a
[calendar](calendar.md) gives a date that day. `program_for(kind)` gives
the program of `"sun"`..`"sat"` or of a special day.

A special day may be bound to `Timetable::USUAL` instead of a program:
a calendar entry for that day then applies to the zone, which runs its
usual weekday ([calendar.md](calendar.md#overlaps-and-priority) says
why that differs from having no binding). It binds special days only;
on a weekday it raises `Error`.

## How a time is resolved

`Timetable#at(time)` gives the `Timetable::Resolution` in force: the
`preset`, the `strategy` overriding its own (nil if none), and the
`chain` of transitions that led there (`Timetable::Said`: the level,
the date its program ran on, the transition). `transition`, `program`,
`level` and `date` read the one holding the preset; `fallback?` is
true when none does and `preset` is the fallback:

1. Take the program of the time's date.
2. Take its last transition at or before the time of day.
3. If there is none yet, take the last transition of the most recent
   earlier day that has one, looking back up to a week. So
   `23:00=night` lasts until the next morning's first transition, and a
   day without a program carries on from the day before.
4. If that transition holds a keyword, follow it (above); with nothing
   in force at all, the chain is empty and the fallback holds.

`Timetable#next_change(time)` is the first time after the time,
looking ahead up to a week, when the chain changes: every transition
that comes to decide is a change, even one holding the same preset as
before; one that stays hidden (under a calendar day's program) is not;
nil if there is none.

With `work` every day:

```text
        06:45    08:30                   23:00   00:00     06:45
──────────┬────────┬───────────────────────┬───────┼─────────┬────────▸
   night  │comfort │          eco          │      night      │ comfort
Monday                                             Tuesday
```

Both take `fallback:` (`Preset::FROST`) and an optional block giving
the stack of a date: its `Timetable::Level`s (`program`, nil for a
weekday without one; `entry`, the calendar entry it runs for, nil for
the weekday's own; `weekday`, true for the weekday's, also when an
entry bound to `usual` runs it), best first, the weekday's
last (`Timetable#weekday(date)`, the only one by default); that is how
the calendar runs other days. `Timetable#resolver(fallback:, &levels)`
gives the `Timetable::Resolver` both use, to ask several times about
the same stacks.

Times are local wall-clock times in the process's time zone; a Time
given in another offset (UTC) is taken as the same moment, its date the
local one. On the
night clocks go forward, a transition in the missing hour (02:30)
happens when they jump, at 03:00, so a 03:10 transition still comes
after it; on a date they skip altogether, its transitions happen
when they jump, the last one holding; on the night they go back, at
the first 02:30, and only then: what is in force is decided by the
moment, not the clock reading, so `at` and `next_change` agree
through the repeated hour.

## The layer

`Layers::Timetable.new(fallback: Preset::FROST)` decides from the
zone's timetable: the transition's preset, the transition's strategy
over the preset's, source `timetable:PROGRAM`, `until` the next change.
A zone with no transition within the week before, or whose program's
keyword lets the fallback through, holds the fallback, source
`fallback`, `until` the next change (none for the first).
