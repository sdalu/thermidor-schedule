# frozen_string_literal: true

require "date"

module Thermidor
    module Schedule
        # The weekly cycle of one zone: a Program per weekday (0 is Sunday,
        # as Time#wday), and per special day ("holiday") for the calendar
        # to call on. A day without a program, or before its first
        # transition, carries on from the last transition of an earlier day.
        Timetable = Data.define(:days, :specials) do
            def initialize(days: {}, specials: {})
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
            def at(time, &lookup)
                lookup ||= ->(date) { days[date.wday] }
                (0..7).each do |back|
                    date = time.to_date - back
                    program = lookup.call(date) or next
                    upto = back.zero? ? minute(time) : DAY_MINUTES
                    transition = program.at(upto) or next
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
                    from  = ahead.zero? ? minute(time) : -1
                    later = program.after(from) or next
                    return local(date, later.minute)
                end
                nil
            end

            private

            def minute(time) = (time.hour * 60) + time.min

            # Local wall-clock time; Time.new moves a time that falls in
            # a daylight-saving gap forward, as clocks do.
            def local(date, minute)
                Time.new(date.year, date.month, date.day, *minute.divmod(60))
            end
        end

        class Timetable
            # What is in force at a given time: which program, which of its
            # transitions, and the date that program ran on.
            Entry = Data.define(:program, :transition, :date)
        end
    end
end
