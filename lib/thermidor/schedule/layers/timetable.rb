# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # The base layer: the zone's weekly timetable, or the fallback
            # preset for a zone that has none.
            class Timetable
                def initialize(fallback: Preset::FROST)
                    raise Error, "a timetable layer needs a fallback" unless
                        fallback
                    @fallback = fallback
                end

                def apply(zone, now, _below)
                    entry = zone.timetable.at(now) or return fallback(zone)
                    Decision.from_preset(
                        entry.transition.preset, zone,
                        override: entry.transition.strategy,
                        source: "timetable:#{entry.program.label}",
                        until: zone.timetable.next_change(now)
                    )
                end

                private

                def fallback(zone)
                    Decision.from_preset(@fallback, zone, source: "fallback",
                                                          until: nil)
                end
            end
        end
    end
end
