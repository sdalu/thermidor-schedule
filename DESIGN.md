# Design

## Where it came from

The schedule was `ClimatControl::Schedule`, the part of ClimatControl
that decides what each zone of a house should hold. It used nothing of
the rest (no device, no database, no presence backend), so it moved
into its own gem, its code unchanged but for its namespace, to be
paired later with a planner of the same family (`thermidor-planner`).
ClimatControl keeps what is its own: the SQLite store the entries live
in, the command line, and the planner that turns decisions into device
settings. What each layer does with its entries is in doc/ here; the
commands that make those entries are in ClimatControl's doc/schedule/.

## A band, not a target

A zone holds a band: heat below one setpoint, cool above another, do
nothing in between. A single target would have a radiator and an air
conditioner in the same room take turns around it; at least `DEADBAND`
(1 °C) between the sides keeps them apart. A nil side means never act
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

## Recurrence: iCalendar's, for whole days

Recurring calendar entries use RFC 5545's RRULE, the form CalDAV and
every calendar application speak, restricted to whole days (no time
parts); its first date is always the first occurrence, as in
iCalendar. A home-made notation would have been shorter to parse and
impossible to import.

## Local time

Times are local wall-clock times in the process's time zone, as a
house's timetable is: a program's 06:30 is 06:30 on either side of a
daylight-saving change, and a transition in the spring gap moves
forward as clocks do (`Time.new`).

## Strategies and the deadband are the family's

`STRATEGIES` (comfort, cheapest, quiet, quick) are the planner's
vocabulary, and `DEADBAND` a choice about devices sharing a room.
They stay constants here for the first release: the planner to come is
of the same family and shares them, and ClimatControl is the only
user. Should another user need its own strategies, they become a
parameter of `Schedule.strategy` and of the values that validate one
(`Preset`, `Transition`, `Zone`), and the deadband a parameter of
`Setpoint` and `Layers::Clamp`.
