# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # The bounds of a zone's guards, one axis at a time (Guard).
            class Guard
                # A bound and the guard that gave it.
                Bound = Data.define(:value, :name)

                # The tightest floor and ceiling the guards give on one axis,
                # each a Bound or nil; on a tie, the first guard's.
                Span = Data.define(:low, :high) do
                    def self.tightest(entries, low, high)
                        new(low: pick(entries, low, :max_by),
                            high: pick(entries, high, :min_by))
                    end

                    def self.pick(entries, side, by)
                        entries.filter_map do |entry|
                            value = side.call(entry.bounds)
                            Bound.new(value:, name: entry.name) if value
                        end.public_send(by, &:value)
                    end

                    def bounds = [low&.value, high&.value]

                    def given? = !(low.nil? && high.nil?)

                    # The floor and the ceiling less than `gap` apart (a
                    # floor above the ceiling); with `touching`, at it too.
                    def narrower?(gap, touching: false)
                        return false unless low && high
                        width = (high.value - low.value).round(1)
                        touching ? width <= gap : width < gap
                    end

                    def within(value)
                        floor, ceiling = bounds
                        value = [value, floor].max if value && floor
                        value = [value, ceiling].min if value && ceiling
                        value
                    end

                    # The guard that moved a temperature side from `from` to
                    # `to`: one taken down is the ceiling's, up the floor's,
                    # wherever it lands; an open side is its own bound's.
                    def mover(from, to, own)
                        return holder(to, own) if from.nil?
                        (to < from ? high : low).name
                    end

                    # The guard whose bound (:low or :high, `own`) a side now
                    # holds; one dropped, or pushed past it, is the
                    # opposite's.
                    def holder(to, own)
                        mine, other = own == :low ? [low, high] : [high, low]
                        (to && mine&.value == to ? mine : other)&.name
                    end
                end
            end
        end
    end
end
