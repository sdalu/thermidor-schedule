# Guard

`Layers::Guard` sits above every layer that decides and below the
[clamp](clamp.md): whatever was decided under it (the timetable, away,
a manual setting, a boost, an open window), the zone stays within the
limits of the guards it holds. A guard is a band read as bounds, not as
a target: its heat side is a floor, its cool side a ceiling, and its
humidity bounds bound the humidity.

```ruby
Layers::Guard.new([
    Layers::Guard::Entry.new(zone: "bedroom", name: "frost",
                             bounds: Syntax.guard("+7..")),
    Layers::Guard::Entry.new(zone: "bedroom", name: "damp",
                             bounds: Syntax.guard("@..65")),
    Layers::Guard::Entry.new(zone: "bedroom", name: "floor-bamboo",
                             bounds: Syntax.guard("+15..+25@40..65"))
])
```

The entries are the guards in force: which guards a zone holds, and
whether one applies only when away or only when occupied, is the
caller's to work out before building the layer. Hand them over in a
stable order (by name, say): of guards giving the same bound, the first
listed is the one named. A zone with no entry passes through untouched.

## Suspended for a while

Most damage is slow: a room at 27 °C for an hour cooks no floor. A
guard may name the layers that suspend it (`suspended_by:`, a layer
being a source's first part: `manual`, `boost`, `open-window`, `away`
for `away` and `away:auto`). While the decision below comes from one
of them **and has an end of its own** (`Decision#ends`: a manual
setting's, a boost's, an open window's or a dated away's `ends_at`),
the guard is set aside; the zone's other guards still hold. A setting
with no end never suspends a guard: `+28..` forever stays under a
ceiling, even with another entry queued after it, in its layer or one
above. That brings `until` forward, the next change, but the forever
setting may come back once the queued one is over. Automatic away has
no end either.

```ruby
Layers::Guard::Entry.new(zone: "bedroom", name: "bamboo-ceiling",
                         bounds: Syntax.guard("..+25@..65"),
                         suspended_by: %w[manual boost])
```

A guard whose floor and ceiling must both hold apart is better split:
the bedroom's bamboo as `bamboo-floor` (`+15..@40..`, never suspended)
and `bamboo-ceiling` (`..+25@..65`, suspended by a manual setting or a
boost). Then, the timetable holding `+20..+24`:

| Below                    | `ends`  | After the guards | `suspended`                         |
| :----------------------- | :------ | :--------------- | :---------------------------------- |
| timetable `+20..+24`     | nil     | `+20.0..+24.0`   | `{}`                                |
| boost `+28..`, 30 min    | 14:30   | `+28.0..`        | `{ "bamboo-ceiling" => "boost" }`   |
| manual `off`, 2 h        | 16:00   | `+15.0..`        | `{ "bamboo-ceiling" => "manual" }`  |
| manual `+28..`, forever  | nil     | `+24.0..+25.0`   | `{}`                                |
| open window, 15 min      | 14:15   | `+15.0..+25.0`   | `{}`                                |

(humidity bounds left out). The open window suspends nothing here, so
the ceiling cools under it; `suspended_by: %w[manual boost open-window]`
would set it aside for the window's length, at most two hours.
Frost is suspended by nothing.

The guards are checked when the layer is built as a whole, the
suspendable included: a set holding a band holds one with any of its
guards set aside. A layer named is lowercase, letters, digits, `_` or
`-` (`Error` otherwise); any layer's source may be named, the caller's
own included.

## Several guards

A zone's guards intersect: the highest floor, the lowest ceiling, on
each axis. Guards that leave no band between them are refused when the
layer is built, with `Error`, as the clamp refuses such limits: a floor
and a ceiling less than the deadband apart (`+24.6..` with `..+25`, or
`+24..` with `..+25` under a deadband of 2), a humidity floor at or
above a humidity ceiling. The caller is expected to refuse them
earlier, where the guards are given; the layer is a backstop, and one
zone's bad set refuses the whole layer. An entry bounding nothing
(`off`, `@`), or given no `Setpoint`, is refused as well.

## What changes

Each side of the band below is brought within the guards' floor and
ceiling, at both ends: heat above a ceiling comes down to it, cool
under a floor goes up to it. This goes beyond "heat no lower than the
floor, cool no higher than the ceiling": with that alone, `+28..` under
`+15..+25` would heat to 28 and cool from 29, the bamboo floor cooked
while its guard is in force. An open side takes its own bound: `off`
in a room guarded `+15..+25` becomes `+15..+25`, and in one guarded
only `+7..` becomes `+7..`. When the sides end up closer than the
deadband, the cooling side gives way first, up to the ceiling, then
the heating side, as in the clamp; since the guards are at least the
deadband apart, every side stays within every guard.

A ceiling guard therefore cools even under an open window, whose
preset leaves the cool side open, unless the window suspends it (see
above); a floor-only guard (`+7..`) does not cool at all.

The humidity bounds below (given, kept, or cleared with `@`) are
brought within the guards' alike. A humidity bound has no gap to keep
from the other, so where a heat side pushed under a ceiling is held
just short of it, a humidity floor pushed onto the guards' ceiling is
dropped: it gives way to the guards' floor, or to none; a ceiling
pushed onto their floor, to their ceiling.

With the bedroom's guards above (`+15..+25@40..65`, the intersection):

| Below             | After the guards      | `guards`                                           |
| :---------------- | :-------------------- | :------------------------------------------------- |
| `+20..+24@45..60` | `+20.0..+24.0@45..60` | `{}`                                               |
| `off`             | `+15.0..+25.0@40..65` | heat, cool, humidity_low: floor-bamboo; humidity_high: damp |
| `+28..`           | `+24.0..+25.0@40..65` | heat, cool, humidity_low: floor-bamboo; humidity_high: damp |
| `+20..+24@70..`   | `+20.0..+24.0@40..65` | humidity_low: floor-bamboo; humidity_high: damp    |

## What the decision says

The band changes; the strategy, `source`, `label`, `until` and `ends` of the
decision pass through, so the decision still names the layer that
decided. `humidity_source` passes through too, unless the guards gave
humidity bounds where none were in force (none given, or cleared with
`@`): it is then `"guard"` (`Guard::SOURCE`).

`Decision#guards` names, for each side a guard moved, the guard that
bound it: `:heat`, `:cool`, `:humidity_low`, `:humidity_high`. A
temperature side taken down is the ceiling's guard, one taken up the
floor's, wherever it lands (heat stepping down under a ceiling is the
ceiling's, even onto a floor); an open side that took a bound is that
bound's guard. A humidity side is named for the guard whose bound it
now holds (a floor of 70 dropped to the bedroom's 40 is floor-bamboo's),
or, dropped to none, for the guard whose ceiling dropped it. A side
left where it was is not named, and `guards` is empty
(`Decision::NO_GUARDS`) when no guard moved anything.
`Decision#suspended` names each guard set aside, with the source that
suspended it (`{ "bamboo-ceiling" => "boost" }`), `{}` when none was.
Two guard layers stacked add to each other's: the upper one names the
sides it moved over those the lower one named, and its suspended
guards to the lower one's.

The clamp above still applies: a guard's floor above the clamp's
limits (`Clamp::LIMITS`, 5 to 30 °C) is brought back within them, and
`guards` still names the guard. A caller had better refuse such a bound
where the guard is given.
