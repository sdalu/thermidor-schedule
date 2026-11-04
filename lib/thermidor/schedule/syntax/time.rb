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
            DURATION = /\A(?:(?<h>\d+)h)?(?:(?<m>\d+)m?)?\z/

            module_function

            # "2027" or "2027..2029" => 2027..2029
            def years(text)
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
                match = DURATION.match(text)
                hours, minutes = match&.values_at(:h, :m)
                raise ParseError, "bad duration #{text.inspect}" unless
                    hours || minutes
                ((hours.to_i * 60) + minutes.to_i) * 60
            end

            # "2026-12-25" or "2026-12-24..2026-12-26" => [first, last]
            def dates(text)
                first, last = text.split("..", 2).map { Date.iso8601(it) }
                last ||= first
                raise ParseError, "#{text} ends before it starts" if
                    last < first
                [first, last]
            rescue Date::Error
                raise ParseError, "bad date #{text.inspect}"
            end

            # "2026-11-02 07:00" or "07:00" (on the day of `now`).
            def time(text, now = Time.now)
                match = DATE.match(text)
                date  = match ? Date.iso8601(match[:date]) : now.to_date
                hour, min = minute(match ? match[:clock] : text).divmod(60)
                Time.new(date.year, date.month, date.day, hour, min)
            rescue Date::Error
                raise ParseError, "bad date #{text.inspect}"
            end
        end
    end
end
