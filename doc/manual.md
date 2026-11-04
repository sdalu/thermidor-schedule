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
| `mode`      | how its end was asked for (below); kept, not read    |

When several entries are active in a zone, the **last in the list**
wins, so the caller lists them oldest first. A setting replaced by a
newer one is usually ended rather than paused: the caller ends it, so
that when the newer one ends the zone goes back to the layers below,
not to what was left of the older one.

## How long

The end is fixed when the setting is made, and the layer only reads
`ends_at`. `mode` records how it was asked for:

| `mode`     | `ends_at`                                       |
| :--------- | :---------------------------------------------- |
| `:for`     | the end of a duration, up to `Manual::LONGEST` (12 h) |
| `:next`    | the next change of the layers below, at that moment |
| `:forever` | nil                                             |

For `:next`, the caller asks the stack below the manual layer (e.g.
`Stack.new(lower_layers).wake_at(zone, now)`) when the setting is made.
Worked out live instead, it would never end: there is always a next
change. `LONGEST` is not checked by the layer; it is there for the
caller.

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
