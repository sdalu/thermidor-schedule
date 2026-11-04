# frozen_string_literal: true

module Thermidor
    module Schedule
        # Layers, bottom first. Each one gets the decision of the layers
        # below and returns it unchanged when inactive, or its own.
        class Stack
            attr_reader :layers

            def initialize(layers)
                @layers = layers.dup.freeze
            end

            def resolve(zone, now) = decisions(zone, now).last

            # When to look again: the earliest change anywhere in the
            # stack, since a lower change can show through a relative layer.
            def wake_at(zone, now)
                decisions(zone, now).filter_map(&:until).min
            end

            # The decision after each layer, bottom first.
            def decisions(zone, now)
                below = nil
                layers.map { below = it.apply(zone, now, below) }
            end
        end
    end
end
