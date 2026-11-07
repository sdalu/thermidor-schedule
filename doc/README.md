# The schedule and its layers

thermidor-schedule works out, for a zone at a given moment, what the
zone should be doing: which comfort band to hold, how its devices
should share the work, which layer decided it, and when that may
change. It decides only. Where presets, programs and entries are kept,
and what the devices are told, is the caller's.

- [Concepts](#concepts)
- [The layer stack](#the-layer-stack)
- [A decision](#a-decision)
- [The layers](#the-layers)
- [What the caller keeps](#what-the-caller-keeps)

## Concepts

| Term     | Class                  | Meaning                                                  |
| :------- | :--------------------- | :------------------------------------------------------- |
| band     | `Setpoint`             | heat below `heat`, cool above `cool` (nil: never)        |
| humidity | `Humidity`             | a band's optional floor and ceiling, % relative humidity |
| strategy | a Symbol               | how the devices combine (configured; comfort by default) |
| preset   | `Preset`               | a band, named or not, with an optional strategy          |
| program  | `Program`              | one day: `Transition`s, a preset from a time of day on   |
| week     | `Timetable`            | a program per weekday, and per special day               |
| zone     | `Zone`                 | a name, an optional strategy, a timetable                |
| layer    | anything with `apply`  | one source of decisions; the highest active one wins     |
| decision | `Decision`             | what the stack settled on                                |

A zone is a room as the schedule sees it. Which devices it holds is
the caller's business.

## The layer stack

`Stack.new(layers)` takes the layers bottom first, at least one
(`ArgumentError` for none). Each one receives
the decision of the layers below it and either passes it through
unchanged (it is inactive) or returns its own. The topmost active layer
therefore wins, and when it ends, whatever is below shows through
again. No layer needs to remember what to restore.

```text
             decision
                ▴
┌───────────────┴────────┐
│ Clamp                  │  always: both setpoints within limits
├────────────────────────┤
│ OpenWindow             │  a window open
├────────────────────────┤
│ Boost                  │  a short push
├────────────────────────┤
│ Manual                 │  set by hand
├────────────────────────┤
│ Away                   │  nobody home
├────────────────────────┤
│ Calendar               │  dates that run another day
├────────────────────────┤
│ Timetable              │  always: the zone's week
└────────────────────────┘
```

That is the order ClimatControl uses. The stack enforces none of it:
it applies whatever it is given, in the order given.

```ruby
stack = Thermidor::Schedule::Stack.new([
    Layers::Timetable.new, Layers::Calendar.new(calendar_entries),
    Layers::Away.new(away_entries), Layers::Manual.new(manual_entries),
    Layers::Boost.new(boost_entries),
    Layers::OpenWindow.new(window_entries), Layers::Clamp.new
])
stack.resolve(zone, now)    # the decision
stack.decisions(zone, now)  # the decision after each layer, bottom first
stack.wake_at(zone, now)    # the earliest change anywhere in the stack
```

Because each layer sees the decision below it, a layer can adjust it
rather than replace it: the clamp changes only the band, and automatic
away, before it starts, only brings `until` forward.

A layer is anything answering `apply(zone, now, below)` with a
`Decision`. `below` is nil for the bottom layer, so only a layer that
needs nothing below (the timetable) can go first.

## A decision

| Field      | Example                       | Meaning                                       |
| :--------- | :---------------------------- | :-------------------------------------------- |
| `setpoint` | `Setpoint(heat: 20, cool: 26)`| the band to hold                              |
| `strategy` | `:quick`                      | how to hold it; always resolved               |
| `source`   | `"calendar:fr:holiday"`       | which layer decided, and on what grounds      |
| `label`    | `"comfort"`                   | the preset's name; nil for an inline band     |
| `until`    | `2026-11-24 08:15`            | when the deciding layer next changes; nil: no change planned |
| `humidity_source` | `"timetable:work"`     | which layer gave the band's humidity bounds; nil: none did |

A band's humidity bounds (`setpoint.humidity`) are not replaced as its
sides are. A manual setting, a boost, an open window or away whose
preset gives none keeps the bounds of the decision below, and
`humidity_source` still names the layer that gave them; a preset
giving `@` (`Humidity::NONE`) clears them. The timetable and the
calendar decide afresh: a holiday's program does not keep a weekday's
bounds. Nothing acts on them yet: they are for the caller and, later,
the planner.

`Stack#wake_at` is the earliest `until` of all the layers, not only the
deciding one's. A change underneath can show through a layer that
adjusts, so that is the moment to look again.

The strategy is the first one given, from the most specific level
down:

```text
transition (or the entry's) ─▸ preset ─▸ zone ─▸ the configured default (comfort)
```

The house-wide level ClimatControl adds sits in that chain as the
zone's: the caller gives each `Zone` its own strategy or the house's.

| Source              | Decided by                                          |
| :------------------ | :-------------------------------------------------- |
| `timetable:PROGRAM` | the zone's week (the program's name, or `(inline)`) |
| `fallback`          | nothing: no transition within the week before       |
| `calendar:NAME:DAY` | an entry of calendar NAME, running DAY              |
| `away`              | an away entry                                       |
| `away:auto`         | automatic away                                      |
| `manual`            | a manual entry                                      |
| `boost`             | a boost entry                                       |
| `open-window`       | an open-window entry                                |

The clamp keeps the source of the decision it clamps.

## The layers

Each has a page, from the bottom of the stack up:

| Layer                         | Active                       | Holds                         |
| :---------------------------- | :--------------------------- | :---------------------------- |
| [Timetable](timetable.md)     | always                       | the zone's week, or `frost`   |
| [Calendar](calendar.md)       | on the dates of its entries  | the program of another day    |
| [Away](away.md)               | an entry, or automatic away  | `away`, or the entry's preset |
| [Manual](manual.md)           | an entry                     | the entry's preset            |
| [Boost](boost.md)             | an entry                     | a `boost` preset              |
| [OpenWindow](open-window.md)  | an entry                     | `open-window`                 |
| [Clamp](clamp.md)             | always                       | the band, within limits       |

The text forms of bands, presets, programs, days, dates and durations
are in [syntax.md](syntax.md).

## What the caller keeps

The layers take plain values (`Data`). They read no store, no clock
(`now` is given) and no presence. That leaves the caller to:

- keep presets, programs, timetables and entries, and build the values
  from them for the time asked about;
- give the calendar the entries around that time (ClimatControl gives
  eight days either side, as far as the timetable looks back and
  ahead), with
  recurring entries already expanded (`Calendar::Entry#occurrences`);
- fix each manual, boost or open-window entry's end when the entry is
  made (`Manual.ends_at`, which checks its duration), and end an entry
  when a new one replaces it;
- turn an entry "for the whole house" into one entry per zone, where
  wanted;
- work out when automatic away starts (`AutoAway`) and pass it to the
  away layer;
- keep the system presets (`Preset::SYSTEM`), which the layers fall
  back on, from being deleted.
