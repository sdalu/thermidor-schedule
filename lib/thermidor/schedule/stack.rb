# frozen_string_literal: true

module Thermidor
    module Schedule
        # Layers, bottom first. Each one gets the decision of the layers
        # below and returns it unchanged when inactive, or its own.
        class Stack
            attr_reader :layers

            # At least one layer (ArgumentError otherwise): the bottom one
            # always decides.
            def initialize(layers)
                raise ArgumentError, "a stack needs a layer" if layers.empty?
                @layers = layers.dup.freeze
            end

            def resolve(zone, now) = decisions(zone, now).last

            # When to look again: the earliest change anywhere in the
            # stack, since a lower change can show through a relative layer.
            def wake_at(zone, now)
                decisions(zone, now).filter_map(&:until).min
            end

            # The decision after each layer, bottom first. Those last asked
            # are kept: a caller asks resolve and wake_at in turn, and a
            # layer is a function of the zone, the moment and the decision
            # below (and of what it was built with), so a second pass would
            # only repeat the first. Dates are read in the process's time
            # zone and bands checked against its settings, so those are
            # part of what was asked too.
            def decisions(zone, now)
                asked = [zone, now, ENV.fetch("TZ", nil), Schedule.config]
                last = @last
                return last.last if last && Stack.same?(last, asked)
                below = nil
                found = layers.map { below = it.apply(zone, now, below) }
                @last = [*asked, found.freeze].freeze
                found
            end

            # The zone and the settings the same objects (values are not
            # compared field by field), the moment and the TZ equal.
            def self.same?(last, asked)
                zone, now, tz, config = asked
                last[0].equal?(zone) && last[1] == now && last[2] == tz &&
                    last[3].equal?(config)
            end
        end
    end
end
