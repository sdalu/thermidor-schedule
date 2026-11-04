# Design

## Where it came from

The schedule was `ClimatControl::Schedule`, the part of ClimatControl
that decides what each zone of a house should hold. It used nothing of
the rest (no device, no database, no presence backend), so it moved
into its own gem, its code unchanged but for its namespace; the
planner that turns decisions into device settings followed as
`thermidor-planner`, the gem of the same family. ClimatControl keeps
what is its own: the SQLite store the entries live in, and the command
line. What each layer does with its entries is in doc/ here; the
commands that make those entries are in ClimatControl's doc/schedule/.

## A band, not a target

A zone holds a band: heat below one setpoint, cool above another, do
nothing in between. A single target would have a radiator and an air
conditioner in the same room take turns around it; at least the
deadband (1 °C unless configured) between the sides keeps them apart. A nil side means never act
on that side, so frost protection is `+7..` and off is no side at all.

## Layers that pass the decision up

Decisions come from a stack of layers, each receiving the decision of
those below and either passing it through or returning its own. So
whatever is below shows through again when a layer ends, and no layer
has to remember what to restore: a manual setting that ends simply
stops answering, and the timetable's program for that hour is there.
Because a layer sees the decision below, it can also adjust rather than
replace it (a boost keeping the band and changing the strategy, an
automatic away that only moves `until`).

`until` on the stack (`wake_at`) is the earliest change anywhere in it,
not only the deciding layer's: a change underneath can show through a
layer that adjusts.

A layer is a duck (`apply(zone, now, below)`), not a subclass of
anything, so a caller adds its own (ClimatControl's "external", a zone
handed to its devices' own drivers, sits above the stack, not in it).

## Values in, decisions out

Every input is an immutable value (`Data`): presets, programs,
timetables, zones and each layer's entries. The layers do not read a
store; the caller reads its own and hands them the entries in force
around the time asked about (ClimatControl gives the calendar a week
either side, as far as the timetable looks back and ahead). A test, or
another caller, builds the same values by hand.

## The calendar decides afresh

A calendar date runs another kind of day: a special day (`holiday`) or
a weekday. The timetable below does not know these dates, and what is
in force early on a holiday may come from the evening before it, so
the calendar layer re-resolves the zone's timetable with its own
lookup rather than patching the decision below. When entries overlap,
the calendar of highest priority wins, then a zone's own entry over a
house-wide one, then the latest added.

An entry for a day the zone has no program for does not apply to it,
like an entry for another zone, so it takes no part in that ranking.
Ranking first and checking the program after made priority reach zones
a calendar says nothing about: a leave calendar raised above public
holidays for the living room turned an office kept cold on holidays
back to a workday. A zone that does want such an entry to win while
running its usual day binds the day to `usual`; that is a keyword, not
a program, so it cannot be confused with one named alike.

## Recurrence: iCalendar's, for whole days

Recurring calendar entries use RFC 5545's RRULE, the form CalDAV and
every calendar application speak, restricted to whole days (no time
parts); its first date is always the first occurrence, as in
iCalendar. A home-made notation would have been shorter to parse and
impossible to import.

The expansion is where ordinals, negative month days and intervals
meet, more cases than examples written by hand cover. So the suite
also compares it with the rrule gem, an independent RFC 5545
implementation, over rules generated from a fixed seed: the comparison
found BYDAY ordinals ignored beside BYMONTHDAY, a day named twice
yielded twice, and a yearly rule without BYMONTH kept in its first
month. rrule is not right everywhere either: it at times keeps a yearly
BYMONTHDAY rule without BYMONTH in its first month, where
python-dateutil and the RFC take every month, so the generator leaves
that case to tests written by hand. rrule is a development dependency
only.

## Local time

Times are local wall-clock times in the process's time zone, as a
house's timetable is: a program's 06:30 is 06:30 on either side of a
daylight-saving change. A transition in the spring gap happens when the
clocks jump, at 03:00, not at 03:30 where `Time.new` puts it: moments
then keep the order of clock readings, so a 03:10 transition still
comes after it. Of a reading that comes twice in autumn, the first.
What is in force and when it next changes are both worked out as
moments, so a caller polling and one sleeping until `until` agree.

## Strategies and the deadband: configured once

The strategies are the planner's vocabulary, and the deadband a choice
about the devices sharing a room: both belong to the house, not to the
schedule. They are set once per process (`Schedule.configure`), which
is one house, and the planner of the same family reads the same
settings, so the two cannot disagree on a strategy's name or on how far
apart a band's sides are.

Passing them to every call was the alternative: no shared state, but
each caller would thread a deadband through `Setpoint`, `Syntax.band`
and the clamp, and a value built without it would silently take the
default. Values still check themselves when built, against the
settings of the time; so the settings are made before anything is
built, and a refused change leaves them as they were.
