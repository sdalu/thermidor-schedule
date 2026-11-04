# frozen_string_literal: true

require "test_helper"

class RecurrenceTest < Minitest::Test
    Schedule = Thermidor::Schedule

    # rule, first date, up to => expected dates (YYYY-MM-DD)
    CASES = {
        ["FREQ=WEEKLY;BYDAY=WE;UNTIL=20261118", "2026-11-04", "2027-12-31"] =>
            %w[2026-11-04 2026-11-11 2026-11-18],
        ["FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR", "2026-11-02", "2026-11-30"] =>
            %w[2026-11-02 2026-11-06 2026-11-16 2026-11-20 2026-11-30],
        ["FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=25", "2026-12-25", "2028-12-31"] =>
            %w[2026-12-25 2027-12-25 2028-12-25],
        ["FREQ=MONTHLY;BYDAY=-1FR;COUNT=3", "2026-11-27", "2030-01-01"] =>
            %w[2026-11-27 2026-12-25 2027-01-29],
        ["FREQ=MONTHLY;BYDAY=MO,2TU", "2026-11-02", "2026-11-30"] =>
            %w[2026-11-02 2026-11-09 2026-11-10 2026-11-16 2026-11-23
               2026-11-30],
        ["FREQ=MONTHLY;BYMONTHDAY=31", "2026-10-31", "2027-03-31"] =>
            %w[2026-10-31 2026-12-31 2027-01-31 2027-03-31],
        ["FREQ=MONTHLY;BYMONTHDAY=-1", "2027-01-31", "2027-03-31"] =>
            %w[2027-01-31 2027-02-28 2027-03-31],
        ["FREQ=DAILY;INTERVAL=3;COUNT=3", "2026-11-01", "2027-01-01"] =>
            %w[2026-11-01 2026-11-04 2026-11-07],
        ["FREQ=YEARLY;BYMONTH=11;BYDAY=4TH", "2026-11-26", "2028-12-31"] =>
            %w[2026-11-26 2027-11-25 2028-11-23],
        ["FREQ=YEARLY", "2028-02-29", "2036-12-31"] =>
            %w[2028-02-29 2032-02-29 2036-02-29]
    }.freeze

    def test_occurrences
        CASES.each do |(rule, first, upto), expected|
            dates = Schedule::Recurrence.parse(rule)
                                        .occurrences(Date.parse(first),
                                                     Date.parse(upto))
            assert_equal expected, dates.map(&:iso8601), rule
        end
    end

    def test_prints_back_in_icalendar_form
        text = "FREQ=MONTHLY;INTERVAL=2;BYDAY=-1FR;BYMONTH=1,7;UNTIL=20271231"
        assert_equal text, Schedule::Recurrence.parse(text).to_s
        assert_equal "FREQ=DAILY",
                     Schedule::Recurrence.parse("freq=daily;interval=1").to_s
    end

    def test_refuses_what_is_not_supported
        %w[FREQ=HOURLY FREQ=DAILY;BYSETPOS=1 FREQ=WEEKLY;BYDAY=2TU
           FREQ=DAILY;INTERVAL=-2 FREQ=DAILY;COUNT=2;UNTIL=20270101 BYDAY=MO
           FREQ=MONTHLY;BYMONTHDAY=0 FREQ=WEEKLY;WKST=SU FREQ=DAILY;UNTIL=x
           FREQ=YEARLY;BYDAY=1MO].each do |text|
            assert_raises(Schedule::ParseError, text) do
                Schedule::Recurrence.parse(text)
            end
        end
    end
end
