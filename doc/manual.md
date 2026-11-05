# Manual

The layer of the [schedule](README.md) for settings made by hand,
`Layers::Manual`: a zone holds a band someone chose, for a while, then
the layers below take over again. It sits above [away](away.md) and
below [boosts](boost.md), which, like [open windows](open-window.md),
are built on it and take the same entries.

- [Entries](#entries)
- [How long](#how-long)
- [Which band](#which-band)
- [In a decision](#in-a-decision)

## Entries

```ruby
Layers::Manual.new(entries, source: "manual", default: nil)
```

A `Manual::Entry`:

| Field       | Meaning                                              |
| :---------- | :--------------------------------------------------- |
| `zone`      | the zone's name                                      |
| `preset`    | the band to hold; nil for the layer's default        |
| `strategy`  | overrides the preset's when given                    |
| `starts_at` | a Time, included                                     |
| `ends_at`   | a Time, excluded; nil until cleared                  |
| `mode`      | how its end was asked for (below); on a boost entry, its direction instead |

When several entries are active in a zone, the **last in the list**
wins, so the caller lists them oldest first. A setting replaced by a
newer one is usually ended rather than paused: the caller ends it, so
that when the newer one ends the zone goes back to the layers below,
not to what was left of the older one.

An entry still to start is a change ahead when it will win: listed
after the one running, or with none running. `until` then comes no
later than its `starts_at`.

## How long

The end is fixed when the setting is made, and the layer only reads
`ends_at`. `Manual.ends_at` works it out; on a manual entry, `mode`
records how it was asked for:

```ruby
Layers::Manual.ends_at(:next, below: Stack.new(lower_layers), zone:, now:)
Layers::Manual.ends_at(:for, below:, zone:, now:, duration: 5400)
```

| `mode`     | `ends_at`                                       |
| :--------- | :---------------------------------------------- |
| `:for`     | the end of a duration, up to `Manual::LONGEST` (12 h) |
| `:next`    | the next change of the layers below, at that moment |
| `:forever` | nil                                             |

`:next` is the next change of what the stack below the manual layer
decides at that moment, or `LONGEST` ahead when that does not change:
not the next change of a layer it hides. On the eve of a holiday whose
program starts at 09:00, the calendar hides the timetable's 06:30, so
the setting ends at 09:00. Worked out live instead, it would never end:
there is always a next change.

`:for` checks its duration: `check_duration(seconds)` refuses one
outside 0 to `LONGEST` with `Error`, naming the kind (`a manual setting
lasts 0 to 12 hours`). Boosts and open windows answer both with their
own `LONGEST` and name. An unknown mode raises `Error`. The layer itself
reads only `ends_at`: entries built otherwise are not checked.

The same field means something else on a [boost](boost.md#which-band)
entry: there `mode` is the direction pushed (`:both`, `:heat`,
`:cool`), and picks the default preset; how the boost's end was asked
for is not on the entry.

## Which band

The entry's preset, else the layer's `default`. The plain manual layer
has none unless given one, so an entry with no preset and no default
to fall back on is refused when the layer is built (`Error`, naming
the entry's zone). Boosts and open windows always have a default. The
strategy is the entry's, then the preset's, then the zone's, then
`comfort`.

## In a decision

The source is the layer's (`manual` unless given). `until` is the
entry's end, nil when it has none.
