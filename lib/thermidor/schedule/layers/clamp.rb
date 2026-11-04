# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # The last word: keeps both setpoints within what the devices
            # are allowed to aim for, and the deadband between them.
            class Clamp
                LIMITS = (5.0..30.0)

                def initialize(limits: LIMITS)
                    @limits = limits
                end

                def apply(_zone, _now, below)
                    heat = below.setpoint.heat&.clamp(@limits)
                    cool = below.setpoint.cool&.clamp(@limits)
                    heat, cool = separate(heat, cool) if heat && cool
                    below.with(setpoint: Setpoint.new(heat:, cool:))
                end

                private

                # Cool gives way first, up to the upper limit; then heat.
                def separate(heat, cool)
                    cool = [cool, heat + DEADBAND].max
                    cool = [cool, @limits.end].min
                    [[heat, cool - DEADBAND].min, cool]
                end
            end
        end
    end
end
