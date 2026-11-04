# Clamp

The last layer of the [schedule](README.md), `Layers::Clamp`, always
active: whatever the layers below decided, it keeps the band within
what the devices may aim for. It changes the setpoints only. The
strategy, source, label and `until` of the decision pass through.

```ruby
Layers::Clamp.new(limits: Layers::Clamp::LIMITS)   # 5.0..30.0
```

Limits narrower than the deadband, given backwards, or not numbers
would hold no band: the clamp refuses them when built, with `Error`.

| Rule     | Value                 | Why                                         |
| :------- | :-------------------- | :------------------------------------------ |
| range    | `limits`, 5 to 30 °C  | both setpoints stay within what makes sense |
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
guard.
