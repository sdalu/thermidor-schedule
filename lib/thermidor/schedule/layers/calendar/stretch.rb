# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            class Calendar
                # A stretch of a day (`from` to `to`, Times) and what holds
                # it: a preset, the strategy overriding its own, and who said
                # so, as a decision's source.
                Stretch = Data.define(:from, :to, :preset, :strategy, :source)

                # The stretches of `date` as `resolver` resolves it, from its
                # midnight to the next, each Resolution given a source by the
                # block.
                def Stretch.day(resolver, date, &)
                    stop = LocalTime.at(date + 1, 0)
                    from = LocalTime.at(date, 0)
                    stretches = []
                    while from < stop
                        upto = [resolver.next_change(from), stop].compact.min
                        stretches << of(resolver.at(from), from, upto, &)
                        from = upto
                    end
                    joined(stretches)
                end

                def Stretch.of(found, from, to)
                    new(from:, to:, preset: found.preset,
                        strategy: found.strategy, source: yield(found))
                end

                # `stretches` in order, each run of those holding the same
                # made one.
                def Stretch.joined(stretches)
                    runs = stretches.slice_when do |one, two|
                        one.with(from: two.from, to: two.to) != two
                    end
                    runs.map { it.first.with(to: it.last.to) }
                end
            end
        end
    end
end
