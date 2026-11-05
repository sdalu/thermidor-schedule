# Boost

The layer of the [schedule](README.md) for a short push on a zone,
`Layers::Boost`: a band held for some minutes, above [manual](manual.md)
settings and below an [open window](open-window.md). It is a manual
layer with its own source and default presets, and takes the same
`Manual::Entry` values.

```ruby
Layers::Boost.new(entries, defaults: {})
```

## How long

As for [manual settings](manual.md#how-long), `ends_at` is fixed when
the boost is made, and `Boost.ends_at(:for, …)` checks its duration against
`Boost::LONGEST`, an hour (`a boost lasts 0 to 1 hour`). It refuses
`:forever` and `:next` with `ArgumentError`, naming the mode (`a boost
takes no :forever end`): a boost always has an end of its own.
`Boost::DEFAULT`, 30 minutes, is the length to ask for when none is
given. A boost is a short push; a longer one is better made a manual
setting.

## Which band

On a boost entry, `mode` is the direction, not how the end was asked
for as on a [manual entry](manual.md#entries): the end is passed to
`Boost.ends_at` as its own mode and only `ends_at` is kept. An entry
with a preset holds it. Without one, its `mode` says which push was
asked for (one of `Boost::DIRECTIONS`), and so which default:

| `mode`  | Default             | Band             | Pushes       |
| :------ | :------------------ | :--------------- | :----------- |
| `:both` | `Preset::BOOST`     | `+23..+24/quick` | either way   |
| `:heat` | `Preset::BOOST_HEAT`| `+24../quick`    | heating only |
| `:cool` | `Preset::BOOST_COOL`| `..+22/quick`    | cooling only |

Any other mode takes the `:both` default. `defaults:` replaces some or
all of them, by direction (`{ heat: my_heat_preset }`); the built-in
ones stand for the rest.

A boost, like every layer, gives a band rather than an order: heating
happens when the room is below the band, cooling when it is above, and
nothing in between. So the plain boost pushes whichever way the room is
off: a room at 19 °C heats towards 23 °C, one at 28 °C cools towards
24 °C. `:heat` and `:cool` leave the other side of the band open, so
they push one way only.

## In a decision

The source is `boost`, `label` the preset's name, and `until` the
entry's end.
