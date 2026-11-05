# Text forms

`Syntax` reads the notations a command line or a file writes the
[schedule](README.md) in. They read Strings only. Every refusal raises `ParseError` naming what
was refused. References to named presets and programs come back as
their name (a String) for the caller to look up; inline ones come back
as an anonymous `Preset` or `Program`.

- [Bands and presets](#bands-and-presets)
- [Programs](#programs)
- [Days](#days)
- [Dates, times and durations](#dates-times-and-durations)

## Bands and presets

| Call                          | Reads                 | Gives                            |
| :---------------------------- | :-------------------- | :------------------------------- |
| `band("+20.5..+25")`          | `HEAT..COOL`          | `Setpoint(heat: 20.5, cool: 25.0)` |
| `band("+7..")`, `band("..+26")` | one side open       | a one-sided `Setpoint`           |
| `preset("off")`               | `off`                 | an anonymous preset, no side     |
| `preset("+20..+25")`          | a band                | an anonymous preset              |
| `preset("comfort")`           | a name                | `"comfort"`                      |
| `preset_ref("comfort/quick")` | `PRESET/STRATEGY`     | `["comfort", :quick]`            |

A band whose sides are closer than the deadband, or a program with two
transitions at the same time, is refused as a `ParseError` too.

Each number carries its sign, which keeps the decimal point apart from
the `..`, and one decimal at most: `-2..+5`, `+20.5..+25`. At least one
side is required. A name starts with a lowercase letter, then letters,
digits, `_` or `-`. The strategy after `/` goes through
`Schedule.strategy`.

## Programs

| Call                                            | Gives                         |
| :---------------------------------------------- | :---------------------------- |
| `program("work")`                               | `"work"`                      |
| `program("usual")`                              | `Timetable::USUAL`            |
| `program("06:30=comfort,22:30=+17..+27/quiet")` | an anonymous `Program`        |
| `transition("06:30=comfort/quick")`             | a `Transition`, preset `"comfort"` |
| `minute("06:30")`                               | 390                           |

Times are `H:MM` or `HH:MM`, 00:00 to 23:59. `usual` is a keyword, a
special day's binding to the zone's usual weekday, never a program's
name.

## Days

| Call                 | Gives                 |
| :------------------- | :-------------------- |
| `days("mon-fri")`    | `[1, 2, 3, 4, 5]`     |
| `days("fri-mon")`    | `[5, 6, 0, 1]`        |
| `days("sat,sun")`    | `[6, 0]`              |
| `day_keys("holiday")`| `["holiday"]`         |
| `day_kind("Sunday")` | `"sun"`               |

Weekdays are `mon`..`sun` or the full English names, in any case; a
range wraps around the week. No day at all (`""`, `","`) is refused.
`days` takes weekdays only. `day_keys`
gives weekdays, or else one special day's name. `day_kind` gives a
calendar entry's day: `"sun"`..`"sat"` for any weekday spelling, or a
special day's name.

## Dates, times and durations

| Call                                 | Gives                         |
| :----------------------------------- | :---------------------------- |
| `years("2027..2029")`                | `2027..2029`                  |
| `dates("2026-12-24..2026-12-26")`    | `[first, last]`, Dates        |
| `dates("2026-12-25")`                | the same date twice           |
| `time("2026-11-02 07:00")`           | a local Time; on the nights clocks change, a skipped time is the moment they jump, a repeated one the first |
| `time("07:00", now)`                 | 07:00 on `now`'s date         |
| `time("07:00", now, ahead: true)`    | the same, or the next moment the clock reads that time when that is not after `now` (the second pass of a repeated hour, else the next day's, a skipped time still the jump); a dated time is left as it is |
| `duration("1h30")`                   | 5400 (seconds)                |
| `duration("90m")`, `duration("45")`  | 5400, 2700: minutes without a unit |

A range that ends before it starts is refused.
