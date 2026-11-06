# frozen_string_literal: true

require "test_helper"
require "support"

# Recurrence#occurrences(from:) starts the expansion at from's period, not
# at the rule's first date, and gives what the whole expansion gives from
# `from` on: checked against it over rules of every frequency.
class RecurrenceFromTest < Minitest::Test
    Recurrence = Thermidor::Schedule::Recurrence

    RULES = ["FREQ=DAILY", "FREQ=DAILY;INTERVAL=3", "FREQ=DAILY;BYDAY=MO,FR",
             "FREQ=WEEKLY", "FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,SA",
             "FREQ=MONTHLY", "FREQ=MONTHLY;BYDAY=-1FR",
             "FREQ=MONTHLY;INTERVAL=5;BYMONTHDAY=31",
             "FREQ=YEARLY", "FREQ=YEARLY;INTERVAL=4;BYMONTH=2;BYMONTHDAY=29",
             "FREQ=YEARLY;BYMONTH=11;BYDAY=2MO", "FREQ=WEEKLY;COUNT=40",
             "FREQ=DAILY;UNTIL=20250301"].freeze

    FIRSTS = [Date.new(2016, 2, 29), Date.new(2020, 1, 1),
              Date.new(2023, 7, 31)].freeze

    FROMS = [Date.new(2016, 1, 1), Date.new(2024, 2, 29),
             Date.new(2026, 11, 5), Date.new(2027, 1, 1)].freeze

    def test_from_gives_the_whole_expansion_from_then_on
        RULES.product(FIRSTS, FROMS).each do |text, first, from|
            rule = Recurrence.parse(text)
            upto = from + 40
            whole = rule.occurrences(first, upto).select { it >= from }
            assert_equal whole, rule.occurrences(first, upto, from:),
                         "#{text} from #{first}, window #{from}"
        end
    end

    # An entry of three days whose occurrence began before the window
    # still meets it.
    def test_an_entry_s_span_reaches_back_before_from
        entry = ScheduleSupport.holiday(Date.new(2020, 1, 6),
                                        Date.new(2020, 1, 8), calendar: "c")
        rule = Recurrence.parse("FREQ=WEEKLY")
        found = entry.occurrences(rule, Date.new(2026, 11, 20),
                                  from: Date.new(2026, 11, 11))
        assert_equal Date.new(2026, 11, 9), found.first.first
    end
end
