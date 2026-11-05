# frozen_string_literal: true

require "date"

module Thermidor
    module Schedule
        # The weekly cycle of one zone: a Program per weekday (0 is Sunday,
        # as Time#wday), and per special day ("holiday") for the calendar
        # to call on. A day without a program, or before its first
        # transition, carries on from the last transition of an earlier day.
        # A special day bound to USUAL runs the zone's usual weekday.
        Timetable = Data.define(:days, :specials) do
            def initialize(days: {}, specials: {})
                Timetable.check_days(days)
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

            # `time` may be in any offset: dates are local ones.
            #
            # The Entry in force at `time`, nil if there is none. `lookup`
            # gives the program of a date, the weekday's by default.
            # Transitions are compared as moments, not clock readings, so
            # one on a night clocks change happens once, at its
            # next_change.
            def at(time, &lookup)
                time = time.getlocal
                lookup ||= ->(date) { days[date.wday] }
                (0..Timetable::REACH).each do |back|
                    date = time.to_date - back
                    program = lookup.call(date) or next
                    transition = last_by(program, date, time) or next
                    return Timetable::Entry.new(program, transition, date)
                end
                nil
            end

            # Time of the next transition after `time`, nil if none.
            def next_change(time, &lookup)
                time = time.getlocal
                lookup ||= ->(date) { days[date.wday] }
                (0..Timetable::REACH).each do |ahead|
                    date = time.to_date + ahead
                    program = lookup.call(date) or next
                    later = first_after(program, date, time)
                    return local(date, later.minute) if later
                end
                nil
            end

            private

            # The first transition of `program`, run on `date`, after
            # `time`; nil if none.
            def first_after(program, date, time)
                program.transitions.find do |each|
                    local(date, each.minute) > time
                end
            end

            # The last transition of `program`, run on `date`, made by
            # `time`; nil if none.
            def last_by(program, date, time)
                program.transitions.reverse.find do |each|
                    local(date, each.minute) <= time
                end
            end

            def local(date, minute) = LocalTime.at(date, minute)
        end

        class Timetable
            # What is in force at a given time: which program, which of its
            # transitions, and the date that program ran on.
            Entry = Data.define(:program, :transition, :date)

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
