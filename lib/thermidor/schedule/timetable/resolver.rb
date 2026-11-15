# frozen_string_literal: true

module Thermidor
    module Schedule
        class Timetable
            # What is in force at a time and when it next changes, over a
            # stack of programs per date (`levels`, a block giving a date's
            # Levels, the weekday one last) and the fallback below them.
            #
            # The top level decides; before its first transition of the
            # date, the last transition of the top of an earlier date
            # carries on. A transition holding a keyword lets another level
            # decide: pass the next one, usual the weekday one, fallback the
            # fallback preset; at the weekday level pass and usual mean the
            # fallback, there being nothing else. A keyword carried from an
            # earlier date falls into this date's stack from above it. A
            # level reached through a keyword answers alone: its own last
            # transition, from its own earlier dates when it has none yet
            # (the weekday level from earlier weekdays, a calendar entry
            # from the dates it covered before); one with nothing lets the
            # next one answer.
            class Resolver
                def initialize(fallback, &levels)
                    raise Error, "a timetable needs a fallback" unless fallback
                    @fallback = fallback
                    @levels   = levels
                    @memo     = {}
                end

                # The Resolution in force at `time` (any offset: dates are
                # local ones).
                def at(time)
                    time = time.getlocal
                    stack = levels(time.to_date)
                    top = top_by(time) or return resolution([])
                    return follow(top, 0, stack, time, [top]) if
                        top.date == time.to_date
                    follow(top, -1, stack, time, [top])
                end

                # The first time after `time` at which what is in force
                # changes (another transition decides, or the chain that
                # leads to it differs), within REACH dates; nil if none.
                def next_change(time)
                    time = time.getlocal
                    now = at(time).chain
                    candidates(time).lazy.find { at(it).chain != now }
                end

                private

                def levels(date) = (@memo[date] ||= @levels.call(date).freeze)

                # The last transition made by `time` of the top level of
                # its date or, before one, of the latest earlier date's.
                def top_by(time)
                    (0..REACH).each do |back|
                        date = time.to_date - back
                        level = levels(date).first
                        said = said_by(level, date, time) and return said
                    end
                    nil
                end

                # Where `said` (at level `index` of `stack`, -1 above it)
                # leads: its preset, or what its keyword lets through.
                def follow(said, index, stack, time, chain)
                    transition = said.transition
                    return resolution(chain, transition) if transition.preset
                    through = transition.through
                    weekday = stack.size - 1
                    return resolution(chain) if through == :fallback ||
                                                index == weekday
                    from = through == :pass ? index + 1 : weekday
                    answer(from, stack, time, chain)
                end

                # The first level from `index` down with something to say,
                # alone, followed; the fallback if none. A keyword carried
                # from an earlier date can lead back to itself (the level
                # that said it is this date's top): it is in the chain once.
                def answer(index, stack, time, chain)
                    (index...stack.size).each do |each|
                        said = alone(stack[each], time) or next
                        chain += [said] unless chain.last == said
                        return follow(said, each, stack, time, chain)
                    end
                    resolution(chain)
                end

                # The last transition by `time` of `level`, on its date or
                # the latest earlier date it was on; nil if none.
                def alone(level, time)
                    (0..REACH).each do |back|
                        date = time.to_date - back
                        same = levels(date).find { it.same?(level) } or break
                        said = said_by(same, date, time) and return said
                    end
                    nil
                end

                def said_by(level, date, time)
                    transitions = level.program&.transitions or return
                    transition = transitions.reverse.find do |each|
                        LocalTime.at(date, each.minute) <= time
                    end
                    Said.new(level, date, transition) if transition
                end

                def resolution(chain, transition = nil)
                    return Resolution.new(@fallback, nil, chain) unless
                        transition
                    Resolution.new(transition.preset, transition.strategy,
                                   chain)
                end

                # Moments after `time` at which something may change, in
                # order: each level's transitions and each midnight, within
                # REACH dates. Made a date at a time: the first is most
                # often the change, and a week of them made at once is
                # most of what a step costs.
                def candidates(time)
                    Enumerator.new do |out|
                        (0..REACH).each do |ahead|
                            later = moments(time.to_date + ahead)
                                    .select { it > time }
                            later.uniq.sort.each { out << it }
                        end
                    end
                end

                def moments(date)
                    minutes = levels(date).flat_map do |level|
                        level.program&.transitions&.map(&:minute) || []
                    end
                    ([0] + minutes).map { LocalTime.at(date, it) }
                end
            end
        end
    end
end
