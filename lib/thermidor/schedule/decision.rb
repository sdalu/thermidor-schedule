# frozen_string_literal: true

module Thermidor
    module Schedule
        # What the layer stack settled on for a zone: the band to hold,
        # how to hold it, which layer said so (`source`, `label` naming
        # the preset, nil if inline) and the next time it may change (nil:
        # nothing planned).
        Decision = Data.define(:setpoint, :strategy, :source, :label,
                               :until)

        class Decision
            # The decision with `until` brought forward to `time` (nil:
            # left alone), a change ahead it does not make itself.
            def sooner(time)
                return self unless time
                with(until: [self.until, time].compact.min)
            end

            # Strategy: `override` (a transition's), else the preset's,
            # else the zone's, else the default.
            def self.from_preset(preset, zone, source:, until:,
                                 override: nil)
                strategy = Schedule.resolve_strategy(
                    override, preset.strategy, zone.strategy
                )
                new(setpoint: preset.setpoint, label: preset.name,
                    strategy:, source:, until:)
            end
        end

        # A zone as the schedule sees it; devices come later.
        Zone = Data.define(:name, :strategy, :timetable) do
            def initialize(name:, strategy: nil, timetable: Timetable.new)
                super(name:, strategy: Schedule.strategy(strategy),
                      timetable:)
            end
        end
    end
end
