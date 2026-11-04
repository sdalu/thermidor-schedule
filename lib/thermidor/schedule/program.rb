# frozen_string_literal: true

module Thermidor
    module Schedule
        # From `minute` (after midnight) on, `preset` is in force, with
        # `strategy` overriding the preset's own when given.
        Transition = Data.define(:minute, :preset, :strategy) do
            def initialize(minute:, preset:, strategy: nil)
                super(minute:, preset:, strategy: Schedule.strategy(strategy))
            end

            def clock
                hour, min = minute.divmod(60)
                format("%<hour>02d:%<min>02d", hour:, min:)
            end
        end

        # A day template: transitions sorted by time of day. An anonymous
        # program (name nil) is written inline.
        Program = Data.define(:name, :transitions) do
            def initialize(transitions:, name: nil)
                raise Error, "usual is reserved, not a program name" if
                    name == "usual"
                sorted = transitions.sort_by(&:minute).freeze
                if sorted.map(&:minute).uniq.size != sorted.size
                    raise Error, "two transitions at the same time"
                end
                super(name:, transitions: sorted)
            end

            def label = name || "(inline)"

            # Last transition at or before `minute`, nil if none yet.
            def at(minute) = transitions.reverse.find { it.minute <= minute }

            # First transition strictly after `minute`, nil if none.
            def after(minute) = transitions.find { it.minute > minute }
        end
    end
end
