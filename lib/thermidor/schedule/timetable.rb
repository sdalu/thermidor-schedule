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
                if days.value?(Timetable::USUAL)
                    raise Error, "usual binds a special day, not a weekday"
                end
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

            # The Entry in force at `time`, nil if there is none. `lookup`
            # gives the program of a date, the weekday's by default.
            # Transitions are compared as moments, not clock readings, so
            # one on a night clocks change happens once, at its
            # next_change.
            def at(time, &lookup)
                lookup ||= ->(date) { days[date.wday] }
                (0..7).each do |back|
                    date = time.to_date - back
                    program = lookup.call(date) or next
                    transition = last_by(program, date, time) or next
                    return Timetable::Entry.new(program, transition, date)
                end
                nil
            end

            # Time of the next transition after `time`, nil if none.
            def next_change(time, &lookup)
                lookup ||= ->(date) { days[date.wday] }
                (0..7).each do |ahead|
                    date = time.to_date + ahead
                    program = lookup.call(date) or next
                    later = program.transitions.find do |each|
                        local(date, each.minute) > time
                    end
                    return local(date, later.minute) if later
                end
                nil
            end

            private

            # The last transition of `program`, run on `date`, made by
            # `time`; nil if none.
            def last_by(program, date, time)
                program.transitions.reverse.find do |each|
                    local(date, each.minute) <= time
                end
            end

            # Local wall-clock time. One the clocks skip, going forward, is
            # the moment they jump (02:30 is 03:00), so moments keep the
            # order of clock readings; of one that comes twice, when they
            # go back, the first.
            def local(date, minute)
                hour, min = minute.divmod(60)
                time = Time.new(date.year, date.month, date.day, hour, min)
                return jump(time) if (time.hour * 60) + time.min != minute
                earlier = time - 3600
                return earlier if earlier.hour == hour && earlier.min == min
                time
            end

            # The moment the clocks jumped forward, before `time`, which
            # Time.new moved past the gap.
            def jump(time)
                time -= 60 while (time - 60).utc_offset == time.utc_offset
                time
            end
        end

        class Timetable
            # What is in force at a given time: which program, which of its
            # transitions, and the date that program ran on.
            Entry = Data.define(:program, :transition, :date)

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
