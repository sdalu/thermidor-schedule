# frozen_string_literal: true

module Thermidor
    module Schedule
        class Recurrence
            # Reads "FREQ=WEEKLY;BYDAY=WE;UNTIL=20270630" into a Recurrence,
            # refusing the parts of RFC 5545 that are not supported. A
            # leading "RRULE:", as a calendar file writes it, is dropped.
            class Parser
                PARTS = %w[FREQ INTERVAL BYDAY BYMONTHDAY BYMONTH UNTIL COUNT
                           WKST].freeze
                BY_DAY = /\A(?<ordinal>[+-]?[1-5])?(?<day>[A-Z]{2})\z/
                UNTIL  = /\A\d{8}(?:T(?:[01]\d|2[0-3])[0-5]\d[0-5]\dZ?)?\z/
                NUMBER = /\A[+-]?\d+\z/

                def initialize(text)
                    @text = text
                    body   = text.to_s.upcase.delete_prefix("RRULE:")
                    pairs  = body.split(";").map { pair(it) }
                    @parts = pairs.to_h
                    twice = pairs.map(&:first).tally.find { |_, n| n > 1 }
                    refuse!("#{twice.first} twice") if twice
                end

                # "KEY=VALUE" => [key, value], of a part supported.
                def pair(part)
                    key, value = part.split("=", 2)
                    refuse!("#{key} is not supported") unless
                        PARTS.include?(key) && value
                    refuse!("#{key} is empty") if value.empty?
                    [key, value]
                end

                def rule
                    rule = Recurrence.new(
                        freq:, interval: number("INTERVAL", 1..) || 1,
                        by_day:, by_month_day: numbers("BYMONTHDAY", -31..31),
                        by_month: numbers("BYMONTH", 1..12),
                        until: until_date, count: number("COUNT", 1..)
                    )
                    check(rule)
                    rule
                end

                private

                def freq
                    freq = @parts.fetch("FREQ") { refuse!("FREQ is required") }
                    FREQS.find { it.to_s.upcase == freq } or
                        refuse!("FREQ=#{freq} is not supported")
                end

                def by_day
                    @parts.fetch("BYDAY", "").split(",").map do |text|
                        match = BY_DAY.match(text)
                        wday  = match && DAYS.index(match[:day]) or
                            refuse!("bad BYDAY #{text}")
                        [match[:ordinal]&.to_i, wday]
                    end
                end

                # Days of the month may count from its end: -1 is the last.
                def numbers(key, range)
                    @parts.fetch(key, "").split(",").map do |text|
                        value = (Integer(text, 10) if NUMBER.match?(text))
                        refuse!("bad #{key} #{text}") unless
                            value&.nonzero? && range.cover?(value)
                        value
                    end
                end

                def number(key, range)
                    found = numbers(key, range)
                    refuse!("#{key} takes one number") if found.size > 1
                    found.first
                end

                # The last date: a time in UTC (ending in Z) is taken on its
                # local date; any other, on its own.
                def until_date
                    text = @parts["UNTIL"] or return
                    refuse!("bad UNTIL #{text}") unless UNTIL.match?(text)
                    date = Date.strptime(text[0, 8], "%Y%m%d")
                    text.end_with?("Z") ? local_date(date, text) : date
                rescue Date::Error
                    refuse!("bad UNTIL #{text}")
                end

                # The local date of "YYYYMMDDTHHMMSSZ", on `date`.
                def local_date(date, text)
                    hour, min, sec = text[9, 6].scan(/\d\d/).map(&:to_i)
                    Time.utc(date.year, date.month, date.day, hour, min, sec)
                        .getlocal.to_date
                end

                def check(rule)
                    refuse!("UNTIL and COUNT exclude each other") if
                        rule.until && rule.count
                    refuse!("WKST other than MO is not supported") if
                        @parts.fetch("WKST", "MO") != "MO"
                    check_days(rule)
                end

                # What BYMONTHDAY and BYDAY ordinals may go with.
                def check_days(rule)
                    refuse!("BYMONTHDAY is not for FREQ=WEEKLY") if
                        rule.freq == :weekly && rule.by_month_day.any?
                    return unless rule.by_day.any? { |ordinal, _| ordinal }
                    return if ordinals_allowed?(rule)
                    refuse!("BYDAY ordinals need FREQ=MONTHLY, or YEARLY " \
                            "with BYMONTH")
                end

                def ordinals_allowed?(rule)
                    rule.freq == :monthly ||
                        (rule.freq == :yearly && rule.by_month.any?)
                end

                def refuse!(message)
                    raise ParseError, "recurrence #{@text}: #{message}"
                end
            end
        end
    end
end
