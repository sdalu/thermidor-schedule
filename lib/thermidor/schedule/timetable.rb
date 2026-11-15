# frozen_string_literal: true

require "date"

module Thermidor
    module Schedule
        # The weekly cycle of one zone: a Program per weekday (0 is Sunday,
        # as Time#wday), and per special day ("holiday") for the calendar
        # to call on. A day without a program, or before its first
        # transition, carries on from the last transition of an earlier day.
        # A special day bound to USUAL runs the zone's usual weekday. What
        # is in force is resolved by a Resolver, over the weekday programs
        # alone or a stack of programs per date.
        Timetable = Data.define(:days, :specials) do
            def initialize(days: {}, specials: {})
                Timetable.check_days(days)
                Timetable.check_specials(specials)
                super(days: days.compact.freeze,
                      specials: specials.compact.freeze)
            end

            def empty?
                (days.values + specials.values).all? { it.transitions.empty? }
            end

            # The program of a day kind: a weekday ("sun") or a special day.
            def program_for(kind)
                weekday = Syntax::WEEKDAYS.index(kind)
                weekday ? days[weekday] : specials[kind]
            end

            # The weekday level of `date`: its program, nil if none.
            def weekday(date) = Timetable::Level.weekday(days[date.wday])

            # A Resolver whose levels are given by the block (a date's
            # Levels, the weekday one last), the weekday's alone by default.
            # Its keywords that reach the fallback give `fallback`.
            def resolver(fallback: Preset.frost, &levels)
                levels ||= ->(date) { [weekday(date)] }
                Timetable::Resolver.new(fallback, &levels)
            end

            # `time` may be in any offset: dates are local ones.
            #
            # The Resolution in force at `time`. Transitions are compared
            # as moments, not clock readings, so one on a night clocks
            # change happens once, at its next_change.
            def at(time, fallback: Preset.frost, &)
                resolver(fallback:, &).at(time)
            end

            # When what is in force next changes after `time`, nil if
            # nothing does within REACH dates.
            def next_change(time, fallback: Preset.frost, &)
                resolver(fallback:, &).next_change(time)
            end
        end

        class Timetable
            # One program of a date's stack: a calendar entry's (`entry`),
            # or the weekday's (`weekday` true; `entry` then the one bound
            # to USUAL that runs it, if any). `program` is nil for a
            # weekday without one.
            Level = Data.define(:program, :entry, :weekday) do
                def initialize(program:, entry: nil, weekday: false)
                    super
                end
            end

            def Level.weekday(program, entry: nil)
                new(program:, entry:, weekday: true)
            end

            # A transition of `level`'s program, run on `date`.
            Said = Data.define(:level, :date, :transition)

            # What is in force: a preset and the strategy overriding its
            # own (nil: none), and the chain of transitions that led to
            # it, top first; the last holds the preset, or a keyword when
            # it is the fallback's, and the chain is empty when nothing is
            # in force at all.
            Resolution = Data.define(:preset, :strategy, :chain) do
                def fallback? = said.nil?
                def date      = said&.date
                def level     = said&.level
                def program   = level&.program
                def transition = said&.transition
                def on_time    = transition&.on_time

                # The transition holding the preset; nil for the fallback.
                def said
                    last = chain.last
                    last if last&.transition&.preset
                end
            end

            # How many dates back `at` looks for what is in force, and
            # `next_change` ahead for a change: a week.
            REACH = 7

            # Weekdays are keyed 0 to 6 (ArgumentError otherwise) and run
            # programs, never USUAL.
            def self.check_days(days)
                days.each_key do |key|
                    next if key.is_a?(Integer) && key.between?(0, 6)
                    raise ArgumentError, "#{key.inspect} is no weekday (0 to 6)"
                end
                return unless days.value?(USUAL)
                raise Error, "usual binds a special day, not a weekday"
            end

            # Special days are names a calendar entry can reach (ArgumentError
            # otherwise): no weekday spelling ("mon", "mon-fri"), not usual.
            def self.check_specials(specials)
                specials.each_key do |key|
                    next if Schedule.name?(key) && key != "usual" &&
                            !Syntax.weekdays?(key)
                    raise ArgumentError, "#{key.inspect} is no special day"
                end
            end

            # Bound to a special day: a calendar entry for that day applies
            # to the zone, which runs its usual weekday. Not a program: it
            # has no transitions of its own, and "usual" names no program.
            Usual = Data.define do
                def name        = "usual"
                def label       = name
                def transitions = []
            end
            USUAL = Usual.new
        end
    end
end
