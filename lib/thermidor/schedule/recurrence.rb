# frozen_string_literal: true

require "date"

module Thermidor
    module Schedule
        # A recurrence rule in the iCalendar (RFC 5545, CalDAV) form, for
        # whole days: FREQ (DAILY, WEEKLY, MONTHLY, YEARLY), INTERVAL,
        # BYDAY (ordinals such as 2TU or -1FR only when monthly, or yearly
        # with BYMONTH), BYMONTHDAY, BYMONTH, and UNTIL or COUNT. As in
        # iCalendar, the first date is always the first occurrence.
        #
        # by_day holds [ordinal or nil, wday] pairs, wday as in Date#wday.
        Recurrence = Data.define(:freq, :interval, :by_day, :by_month_day,
                                 :by_month, :until, :count) do
            def initialize(by_day:, by_month_day:, by_month:, **)
                super(by_day: by_day.map { it.dup.freeze }.freeze,
                      by_month_day: by_month_day.dup.freeze,
                      by_month: by_month.dup.freeze, **)
            end

            def self.parse(text) = Recurrence::Parser.new(text).rule

            # Starts of the occurrences from `first` (included) on, up to
            # `upto`.
            def occurrences(first, upto)
                return [] if upto < first
                last  = [upto, self.until].compact.min
                found = [first]
                Recurrence::Expansion.new(self, first, last).each do |date|
                    break if count && found.size >= count
                    found << date if date > first
                end
                found
            end

            def to_s
                { "FREQ" => freq.to_s.upcase,
                  "INTERVAL" => (interval if interval > 1),
                  "BYDAY" => by_day_text, "BYMONTHDAY" => list(by_month_day),
                  "BYMONTH" => list(by_month),
                  "UNTIL" => self.until&.strftime("%Y%m%d"), "COUNT" => count }
                    .filter_map { |key, value| "#{key}=#{value}" if value }
                    .join(";")
            end

            private

            def list(values) = (values.join(",") if values.any?)

            def by_day_text
                list(by_day.map do |ordinal, wday|
                    "#{ordinal}#{Recurrence::DAYS[wday]}"
                end)
            end
        end

        class Recurrence
            DAYS  = %w[SU MO TU WE TH FR SA].freeze
            FREQS = %i[daily weekly monthly yearly].freeze
        end
    end
end
