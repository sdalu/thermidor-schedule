# frozen_string_literal: true

module Thermidor
    module Schedule
        class Recurrence
            # Reads "FREQ=WEEKLY;BYDAY=WE;UNTIL=20270630" into a Recurrence,
            # refusing the parts of RFC 5545 that are not supported.
            class Parser
                PARTS = %w[FREQ INTERVAL BYDAY BYMONTHDAY BYMONTH UNTIL COUNT
                           WKST].freeze
                BY_DAY = /\A(?<ordinal>[+-]?[1-5])?(?<day>[A-Z]{2})\z/

                def initialize(text)
                    @text  = text
                    @parts = text.to_s.upcase.split(";").to_h do |part|
                        key, value = part.split("=", 2)
                        refuse!("#{key} is not supported") unless
                            PARTS.include?(key) && value
                        [key, value]
                    end
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
                        value = Integer(text, 10, exception: false)
                        refuse!("bad #{key} #{text}") unless
                            value&.nonzero? && range.cover?(value)
                        value
                    end
                end

                def number(key, range) = numbers(key, range).first

                def until_date
                    text = @parts["UNTIL"] or return
                    Date.strptime(text[0, 8], "%Y%m%d")
                rescue Date::Error
                    refuse!("bad UNTIL #{text}")
                end

                def check(rule)
                    refuse!("UNTIL and COUNT exclude each other") if
                        rule.until && rule.count
                    refuse!("WKST other than MO is not supported") if
                        @parts.fetch("WKST", "MO") != "MO"
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
