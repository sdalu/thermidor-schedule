# Clamp

The last layer of the [schedule](README.md), `Layers::Clamp`, always
active: whatever the layers below decided, it keeps the band within
what the devices may aim for. It changes the setpoints only. The
humidity bounds, strategy, source, label and `until` of the decision
pass through.

```ruby
Layers::Clamp.new                      # the clamp_limits configured, 5.0..30.0
Layers::Clamp.new(limits: 7.0..28.0)   # its own
```

Limits narrower than the deadband, given backwards, open-ended,
excluding their end, or not numbers would hold no band: the clamp
refuses them when built, with `Error`, as `configure` refuses such
`clamp_limits`.

| Rule     | Value                                   | Why                                         |
| :------- | :-------------------------------------- | :------------------------------------------ |
| range    | `limits`, configured, 5 to 30 °C        | both setpoints stay within what makes sense |
| deadband | configured, 1 °C      | a radiator and an aircon never fight        |

Each setpoint is first brought within the range. When the two are then
closer than the deadband, the cooling side gives way first, up to the
top of the range, then the heating side:

| Below      | After the clamp | Because                             |
| :--------- | :-------------- | :---------------------------------- |
| `+2..+40`  | `+5.0..+30.0`   | both outside the range              |
| `+31..+33` | `+29.0..+30.0`  | cool held at 30, so heat steps down |
| `..+3`     | `..+5.0`        | an open side stays open             |

`Setpoint` already refuses bands whose sides are closer than the
deadband. The clamp matters for bands the layers compute, and as a last
guard: it is the one limit every zone has and none names, above the
named [guards](guard.md).
