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

            # The decision after each layer, bottom first. Those of the last
            # zone and moment asked are kept: a caller asks resolve and
            # wake_at in turn, and a layer is a function of the zone, the
            # moment and the decision below (and of what it was built
            # with), so a second pass would only repeat the first.
            def decisions(zone, now)
                last = @last
                return last[2] if last && last[0].equal?(zone) &&
                                  last[1] == now
                below = nil
                found = layers.map { below = it.apply(zone, now, below) }
                @last = [zone, now, found.freeze].freeze
                found
            end
        end
    end
end
