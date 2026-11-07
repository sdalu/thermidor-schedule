# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # The last word: keeps both setpoints within what the devices
            # are allowed to aim for, and the configured deadband between
            # them.
            class Clamp
                LIMITS = (5.0..30.0)

                # Limits narrower than the configured deadband, backwards, or
                # of no numbers would hold no band: refused.
                def initialize(limits: LIMITS)
                    gap = Schedule.config.deadband
                    unless limits.is_a?(Range) && limits.minmax.all?(Numeric) &&
                           limits.end - limits.begin >= gap
                        raise Error, "limits #{limits.inspect} hold no band"
                    end
                    @limits = limits
                end

                def apply(_zone, _now, below)
                    heat = below.setpoint.heat&.clamp(@limits)
                    cool = below.setpoint.cool&.clamp(@limits)
                    heat, cool = Clamp.separate(heat, cool, @limits.end) if
                        heat && cool
                    below.with(setpoint: below.setpoint.with(heat:, cool:))
                end

                # Sides closer than the deadband: cool gives way first, up
                # to `ceiling` (nil: none), then heat. The guards' too.
                def self.separate(heat, cool, ceiling)
                    gap = Schedule.config.deadband
                    return [heat, cool] if (cool - heat).round(1) >= gap
                    cool = [cool, heat + gap].max
                    cool = [cool, ceiling].min if ceiling
                    [[heat, cool - gap].min, cool]
                end
            end
        end
    end
end
