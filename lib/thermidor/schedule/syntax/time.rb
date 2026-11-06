# frozen_string_literal: true

module Thermidor
    module Schedule
        # The text forms of dates, times and durations:
        #
        #   years     2027  2027..2029
        #   dates     2026-12-25  2026-12-24..2026-12-26
        #   time      07:00 (today)  2026-11-02 07:00
        #   duration  2h  90m  1h30 (minutes when no unit)
        module Syntax
            DATE     = /\A(?<date>\d{4}-\d{2}-\d{2})[ T](?<clock>\S+)\z/
            DAY      = /\A\d{4}-\d{2}-\d{2}\z/
            DURATION = /\A(?:(?<h>\d+)h)?(?:(?<m>\d+)m?)?\z/

            module_function

            # "2027" or "2027..2029" => 2027..2029
            def years(text)
                text!(text)
                first, last = text.split("..", 2)
                range = Integer(first, 10)..Integer(last || first, 10)
                raise ParseError, "#{text} ends before it starts" if
                    range.end < range.begin
                range
            rescue ArgumentError, TypeError
                raise ParseError, "bad years #{text.inspect}"
            end

            # "2h", "90m", "1h30" (minutes when no unit) => seconds
            def duration(text)
                text!(text)
                match = DURATION.match(text)
                hours, minutes = match&.values_at(:h, :m)
                raise ParseError, "bad duration #{text.inspect}" unless
                    hours || minutes
                ((hours.to_i * 60) + minutes.to_i) * 60
            end

            # "2026-12-25" or "2026-12-24..2026-12-26" => [first, last]
            def dates(text)
                text!(text)
                first, last = text.split("..", 2).map { date(it) }
                last ||= first
                raise ParseError, "#{text} ends before it starts" if
                    last < first
                [first, last]
            rescue Date::Error
                raise ParseError, "bad date #{text.inspect}: YYYY-MM-DD"
            end

            # "2026-12-25" => Date, the whole form only: Date.iso8601 alone
            # reads "2026-11" or "2026" as the first day.
            def date(text)
                raise Date::Error, "not YYYY-MM-DD" unless DAY.match?(text)
                Date.iso8601(text)
            end

            # "2026-11-02 07:00" or "07:00" (on the day of `now`), read as
            # the timetable reads a transition (LocalTime): a time the
            # clocks skip is the moment they jump, one they repeat the
            # first. With `ahead`, a bare time not after `now` is the next
            # moment the clock reads it: a repeated hour's second pass,
            # else the next day's (a skipped time still the jump).
            def time(text, now = Time.now, ahead: false)
                text!(text)
                match = DATE.match(text)
                return clock_time(text, now, ahead) unless match
                LocalTime.at(date(match[:date]), minute(match[:clock]))
            rescue Date::Error
                raise ParseError, "bad date #{text.inspect}: YYYY-MM-DD"
            end

            # A bare "07:00": on `now`'s date, or the next moment after it.
            def clock_time(text, now, ahead)
                minute = minute(text)
                today  = now.getlocal.to_date
                first  = LocalTime.at(today, minute)
                return first unless ahead && first <= now
                second = LocalTime.second_of(first)
                return second if second && second > now
                LocalTime.at(today + 1, minute)
            end
        end
    end
end
