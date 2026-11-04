# Away

The layer of the [schedule](README.md) for when nobody is home,
`Layers::Away`: a zone holds a frugal band until the period ends. It
sits above the [calendar](calendar.md) and below [manual](manual.md)
settings.

- [Entries](#entries)
- [Which band](#which-band)
- [Automatic away](#automatic-away)
- [In a decision](#in-a-decision)

## Entries

```ruby
Layers::Away.new(entries, default: Preset::AWAY, auto_since: nil)
```

An `Away::Entry` is one zone's period:

| Field       | Meaning                                      |
| :---------- | :------------------------------------------- |
| `zone`      | the zone's name                              |
| `preset`    | the band to hold; nil for the layer's default |
| `starts_at` | a Time, included                             |
| `ends_at`   | a Time, excluded; nil for no end             |

An entry is active from `starts_at` until `ends_at`. When several are
active in a zone, the one that started last wins. When none is, the
layers below show through again:

```text
                   09:00               12:00
timetable  ─ comfort ┬─────── eco ───────┬─────── eco ───────
away                 ┣━━━━━━ away ━━━━━━━┫
result     ─ comfort ┴━━━━━━ away ━━━━━━━┴─────── eco ───────
```

A period "for the whole house" is the caller's to turn into an entry
per zone. That lets one zone's own period (frost protection in an
empty office) win over the house's for as long as both run.

## Which band

The entry's preset, else `default` (`Preset::AWAY`, `+16..+30/cheapest`,
unless the caller passes its own). The strategy follows the usual
order: the preset's, then the zone's, then `comfort`.

## Automatic away

`auto_since` is when an automatic away period starts, or nil when there
is none. The layer does not work it out; `AutoAway` does, from
everyone's presence:

```ruby
AutoAway.new(leave: 20 * 60).start(statuses)
```

A status answers `since`, the Time its state began, and `close?`,
whether its person is home or as good as (not known to be away, or near
on the way back). `start` is nil while anyone is close, or with no
statuses at all; otherwise it is the last departure plus `leave`
seconds (20 minutes unless set), long enough to ride out a phone
dropping off the home network for a moment.

From `auto_since` on, every zone without an active entry of its own
holds the default band. An entry always wins over automatic away.
Before `auto_since`, the decision below passes through with its `until`
brought forward to `auto_since`, so a caller sleeping until then wakes
in time.

## In a decision

The source is `away` for an entry and `away:auto` for automatic away.
`until` is the entry's end, nil when it has none, and always nil for
automatic away, which ends when presence changes, something no layer
can foresee.
