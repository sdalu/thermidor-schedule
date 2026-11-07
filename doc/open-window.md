# Open window

The layer of the [schedule](README.md) for an open window,
`Layers::OpenWindow`: the zone stops heating and cooling, frost
protection aside, until the window is shut again. It sits above
everything but the [guards](guard.md), which still hold the zone
within its limits, and the [clamp](clamp.md). It is a manual layer and takes
the same `Manual::Entry` values; `Steady` tells when a window has been
shut.

- [The layer](#the-layer)
- [When it ends](#when-it-ends)
- [Steady: shut again](#steady-shut-again)

## The layer

```ruby
Layers::OpenWindow.new(entries, default: Preset::OPEN_WINDOW)
```

An entry without a preset holds `default`, `+7..` (frost protection).
The source is `open-window` and `until` the entry's end.

## When it ends

The layer only reads `ends_at`; what ends a window is the caller's:

| `mode`    | Ends                                                       |
| :-------- | :--------------------------------------------------------- |
| `:steady` | when `Steady` says it has settled, at `ends_at` at the latest |
| `:for`    | at `ends_at`                                               |

For a steady window, `ends_at` is a safety limit, `OpenWindow::LIMIT`
(60 minutes) unless asked otherwise. The caller ends the entry earlier
once the room's readings settle. Either way, `OpenWindow::LONGEST`
(2 hours) is the most a caller should allow: a window left open longer
than that was forgotten, and the room should not sit at frost
protection by accident. `OpenWindow.ends_at(:steady, ..., duration:)`
checks it, as for [manual settings](manual.md#how-long); the layer
itself reads only `ends_at`. `OpenWindow.ends_at` takes `:for` and
`:steady` and refuses `:forever` and `:next` with `ArgumentError`,
naming the mode: a window always has
an end of its own.

## Steady: shut again

`Steady#steady?(readings, opened)` tells whether a window opened at
`opened` has been shut again, from the room's `[[Time, °C], ...]`
readings (in any order; those at one moment, from two sensors, count as
their mean). Of those before `opened`, only the last
counts, as the baseline. It must have been open at least `after`
seconds by its last reading, and the readings since must have gone
through three phases, in order:

1. **move**: at least `change` °C away from the baseline (down while
   heating, up while cooling), and on as far as it goes. The baseline
   is the last reading at or before `opened`, the room as it was when
   the window opened; with none, the first reading after;
2. **rebound**: back from that extreme by at least the fraction
   `rebound` of the way it went (1 °C back after a 2 °C dip), the
   window being shut while the device still works;
3. **settle**: from the rebound on, the readings of the last `span`
   seconds all within `tolerance` °C of each other, counting the one in
   force when that span began (the last reading at or before it): a
   sensor read less often than `span` must hold steady across two readings,
   not pass on one.

| Parameter   | Default | Meaning                                |
| :---------- | :------ | :------------------------------------- |
| `span`      | 600     | seconds the readings must settle over  |
| `tolerance` | 0.2     | °C they may spread over that span      |
| `change`    | 2.0     | °C the move must reach                 |
| `rebound`   | 0.5     | share of the move it must come back by |
| `after`     | 900     | seconds open at the least              |

A threshold met exactly counts: readings at the tenth make differences
such as 20.6 - 20.4 = 0.20000000000000284, so each comparison allows a
margin (`Steady::MARGIN`, 10⁻⁶ °C) far below any sensor's precision.

Requiring the move keeps a room that barely reacts, on a mild day,
from looking shut while its window is still open. Requiring the rebound
keeps a room that has cooled as far as it will from looking shut when
it merely stopped moving.

A room at 21 °C, its window opened at 12:00, read every 5 minutes:

| Minute | 0    | 5    | 10   | 15   | 20   | 25   | 30   | 35   | 40   | 45    |
| :----- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :---- |
| °C     | 21.0 | 20.0 | 19.4 | 19.0 | 19.3 | 19.9 | 20.1 | 20.2 | 20.2 | 20.25 |

It moves 2 °C by minute 15, then comes back by half of that (1 °C, to
20.0) at minute 30, where it rebounds. At minute 35 it is not yet
steady: the last 10 minutes reach back before the rebound. At minute
40 they no longer do, and spread over 0.1 °C, so `steady?` is true.
