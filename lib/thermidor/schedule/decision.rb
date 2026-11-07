# frozen_string_literal: true

module Thermidor
    module Schedule
        # What the layer stack settled on for a zone: the band to hold,
        # how to hold it, which layer said so (`source`, `label` naming
        # the preset, nil if inline) and the next time it may change (nil:
        # nothing planned); `ends`, when the setting that decided ends of
        # itself (nil: it has no end, or is no setting: a program), which
        # a change ahead brings no nearer. The band's humidity bounds are
        # those in force, perhaps kept from a layer below:
        # `humidity_source` names the layer that gave them (nil: none
        # did). `guards` names, per side a guard moved (:heat, :cool,
        # :humidity_low, :humidity_high), the guard that bound it;
        # `suspended`, per guard set aside for a while, the source it was
        # suspended by.
        Decision = Data.define(:setpoint, :strategy, :source, :label,
                               :until, :humidity_source, :guards, :suspended,
                               :ends)

        class Decision
            NO_GUARDS = {}.freeze

            def initialize(humidity_source: nil, guards: NO_GUARDS,
                           suspended: NO_GUARDS, ends: nil, **)
                super
            end

            # The decision with `until` brought forward to `time` (nil:
            # left alone), a change ahead it does not make itself.
            def sooner(time)
                return self unless time
                with(until: [self.until, time].compact.min)
            end

            # The decision, with the humidity bounds of `below` (and who
            # gave them) when its band gives none: a layer holding a
            # band over others keeps them.
            def keeping(below)
                kept = below&.setpoint&.humidity
                return self if setpoint.humidity || kept.nil?
                with(setpoint: setpoint.with(humidity: kept),
                     humidity_source: below.humidity_source)
            end

            # Strategy: `override` (a transition's), else the preset's,
            # else the zone's, else the default.
            def self.from_preset(preset, zone, source:, until:,
                                 override: nil)
                strategy = Schedule.resolve_strategy(
                    override, preset.strategy, zone.strategy
                )
                humidity_source = source if preset.setpoint.humidity
                new(setpoint: preset.setpoint, label: preset.name,
                    strategy:, source:, until:, humidity_source:)
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
