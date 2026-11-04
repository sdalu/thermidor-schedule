# The calendar

The layer of the [schedule](README.md) that makes given dates run
another day, `Layers::Calendar`: public holidays, days off, a Sunday
program on a bridge day. `Recurrence` and `Holidays` help fill it.

- [How a day is mapped](#how-a-day-is-mapped)
- [Entries](#entries)
- [Overlaps and priority](#overlaps-and-priority)
- [Recurring entries](#recurring-entries)
- [Public holidays](#public-holidays)

## How a day is mapped

A calendar never names programs. It gives dates a **day**, and each
zone's [timetable](timetable.md) says what that day means for the zone:

```text
┌─────────────┐         zone      runs
│ calendar fr │     ┌─▸ living    its "holiday" program
│ 2026-11-11  │     ├─▸ bedroom   its "holiday" program
│ day holiday ├─────┼─▸ bathroom  its "holiday" program
└─────────────┘     └─▸ office    none: its normal Wednesday
```

The day is a special day (`holiday`, `leave`, any name) or a weekday
(`sun` runs each zone's Sunday program). An entry for a day a zone has
no program for does not apply to that zone, as an entry for another
zone would not: the zone keeps its normal weekday, so one calendar can
serve rooms that should change and rooms that should not.

A zone can also take a day without a program of its own: binding the
day to `Timetable::USUAL` (`usual` in the [text forms](syntax.md#programs))
says the entry applies, and the zone runs its usual weekday. That
matters when calendars overlap, below.

The timetable below knows nothing of these dates. So the calendar does
not patch its decision: it resolves the zone's timetable again, with
each date's program looked up through the calendar. That gets the edges
right:

- the early hours of a holiday carry on from the evening before, until
  the holiday program's first transition (source `timetable:PROGRAM`,
  since the evening's program decided);
- on the eve, the next change is already the holiday's first
  transition, not the usual morning one.

With a `work` program every day and a `holiday` program starting at
09:00, 2026-11-11 a holiday:

| At                 | Holds   | Source                | Until            |
| :----------------- | :------ | :-------------------- | :--------------- |
| 2026-11-10 23:30   | night   | `timetable:work`      | 2026-11-11 09:00 |
| 2026-11-11 07:00   | night   | `timetable:work`      | 2026-11-11 09:00 |
| 2026-11-11 10:00   | holiday | `calendar:fr:holiday` | 2026-11-12 06:45 |

A zone with no program on any date within the week before gets the
decision below, unchanged.

## Entries

`Layers::Calendar.new(entries)` takes `Calendar::Entry` values:

| Field         | Meaning                                                   |
| :------------ | :-------------------------------------------------------- |
| `id`          | an Integer; the highest is the latest added               |
| `calendar`    | the calendar's name, in the source                        |
| `priority`    | 1 or more; the lowest wins                                |
| `zone`        | a zone's name, or nil for every zone                      |
| `kind`        | the day it runs: a special day or `"sun"`..`"sat"`        |
| `first`, `last` | Dates, both included                                    |
| `description` | free text                                                 |

`kind` is already resolved: an entry that takes its calendar's day is
given that day by the caller. So is everything else about a calendar
(switched off, renamed): the layer sees only the entries in force.

## Overlaps and priority

When several entries cover a date for a zone, only those that apply
to it count: for the zone or every zone, and naming a day the zone has
a program for (or `usual`). Of these, the one with the smallest `rank`
wins:

1. the lowest `priority`;
2. an entry for the zone itself over one for every zone;
3. the highest `id`, the latest added.

With a `leave` calendar (priority 5) over 21 to 25 December and `fr`
(priority 8) giving the 24th as `holiday`:

| Zone   | Its special days           | 24 December runs        | Source                 |
| :----- | :------------------------- | :---------------------- | :--------------------- |
| living | `holiday`, `leave`         | its `leave` program     | `calendar:leave:leave` |
| office | `holiday`                  | its `holiday` program   | `calendar:fr:holiday`  |
| study  | `holiday`, `leave=usual`   | its usual Thursday      | `calendar:leave:leave` |

The office has no program for `leave`, so leave does not apply to it
and the holiday does. The study takes leave as a usual day, which wins
over the holiday by priority: on leave, its owner works there even on
a public holiday.

## Recurring entries

`Recurrence` is a rule in the iCalendar form (RFC 5545, the one CalDAV
calendars use), for whole days:

| Part         | Values                                         |
| :----------- | :--------------------------------------------- |
| `FREQ`       | `DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY`         |
| `INTERVAL`   | every n periods (weeks start on Monday)        |
| `BYDAY`      | `MO`..`SU`; `2TU`, `-1FR` monthly, or yearly with `BYMONTH` |
| `BYMONTHDAY` | 1 to 31, or -1 for the last day                |
| `BYMONTH`    | 1 to 12                                        |
| `UNTIL`      | the last date, `YYYYMMDD`                      |
| `COUNT`      | the number of occurrences                      |
| `WKST`       | `MO` only                                      |

```ruby
rule = Recurrence.parse("FREQ=MONTHLY;BYDAY=-1FR")
rule.occurrences(Date.new(2026, 11, 27), Date.new(2027, 1, 31))
# => 2026-11-27, 2026-12-25, 2027-01-29
rule.to_s  # => "FREQ=MONTHLY;BYDAY=-1FR"
```

As in iCalendar, the first date always counts as the first occurrence,
`BYDAY` narrows `BYMONTHDAY` (ordinals included: the last Friday of
those days), a day named twice comes once, and dates a rule cannot
have (31 February) are skipped rather than moved: `FREQ=MONTHLY;BYMONTHDAY=31` from 31 January gives 31 January,
then 31 March. Anything else, or a malformed part, raises `ParseError`
naming it; `UNTIL` and `COUNT` exclude each other.

The layer takes entries already expanded. `Entry#occurrences` expands
one: the entry repeated by its rule up to a date, its range as a
whole, without the occurrences starting on a skipped date (iCalendar's
`EXDATE`):

```ruby
christmas.occurrences(Recurrence.parse("FREQ=YEARLY"), Date.new(2030, 1, 1),
                      skipped: [Date.new(2027, 12, 24)])
# => the 24-25 December entry in 2026, 2028, 2029
christmas.occurrences(nil, upto)   # => [christmas]
```

Occurrences keep the entry's `id`. The caller keeps those that reach
the dates asked about.

## Public holidays

`Holidays.for(region, year)` gives `[[Date, name], ...]` in date order,
computing the holidays that follow Easter (the Meeus, Jones and
Butcher algorithm), for a caller to turn into entries:

| Region              | Holidays                                              |
| :------------------ | :---------------------------------------------------- |
| `fr`                | the 11 of metropolitan France, Whit Monday included   |
| `fr-alsace-moselle` | those, with Good Friday and 26 December               |

An unknown region raises `Error`. Holidays that follow Easter cannot be
written as a recurrence rule, which is why they are computed.

`Holidays.register(region, rules)` adds a region, its holidays given as
the built-in ones are: a name and a fixed `[month, day]`, or days from
Easter Sunday (Easter Monday is `1`, Good Friday `-2`).
`Holidays.regions` lists those known. A region already known, no
holiday, or a rule that is no date (`[2, 30]`, `"May"`) is refused with
`Error`, registering nothing. Like the [configuration](../README.md#configuration),
a registration is the process's.

```ruby
Holidays.register("be", "Nieuwjaar" => [1, 1], "Paasmaandag" => 1)
```
