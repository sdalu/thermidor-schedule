# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # The base layer: the zone's weekly timetable, or the fallback
            # preset for a zone that has none, or whose program lets it
            # through.
            class Timetable
                def initialize(fallback: Preset.frost)
                    raise Error, "a timetable layer needs a fallback" unless
                        fallback
                    @fallback = fallback
                end

                def apply(zone, now, _below)
                    resolver = zone.timetable.resolver(fallback: @fallback)
                    found = resolver.at(now)
                    source = "timetable:#{found.program&.label}"
                    source = "fallback" if found.fallback?
                    Decision.from_preset(
                        found.preset, zone,
                        override: found.strategy, source:,
                        until: resolver.next_change(now)
                    ).with(on_time: found.on_time)
                end
            end
        end
    end
end
