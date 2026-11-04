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

    # BYDAY narrows BYMONTHDAY, ordinals included: of the last two days
    # of October, the last Friday or Saturday.
    def test_byday_ordinals_narrow_month_days
        rule = Schedule::Recurrence.parse(
            "FREQ=YEARLY;BYMONTH=10;BYDAY=-1SA,-1FR;BYMONTHDAY=-2,-1"
        )
        assert_equal %w[2026-10-30 2026-10-31 2027-10-30],
                     rule.occurrences(Date.new(2026, 10, 30),
                                      Date.new(2028, 9, 30)).map(&:to_s)
    end

    # Without BYMONTH, a yearly rule's days are taken in every month.
    def test_yearly_without_bymonth_spans_the_year
        mondays = Schedule::Recurrence.parse("FREQ=YEARLY;BYDAY=MO;COUNT=6")
        assert_equal %w[2026-01-05 2026-01-12 2026-01-19 2026-01-26
                        2026-02-02 2026-02-09],
                     mondays.occurrences(Date.new(2026, 1, 5),
                                         Date.new(2027, 1, 1)).map(&:to_s)
        fifteenths = Schedule::Recurrence.parse("FREQ=YEARLY;BYMONTHDAY=15")
        assert_equal %w[2026-01-15 2026-02-15 2026-03-15],
                     fifteenths.occurrences(Date.new(2026, 1, 15),
                                            Date.new(2026, 3, 31)).map(&:to_s)
    end

    # As python-dateutil gives it; the rrule gem stays in January.
    def test_every_other_year_without_bymonth_spans_the_year
        rule = Schedule::Recurrence.parse(
            "FREQ=YEARLY;INTERVAL=2;BYMONTHDAY=31;UNTIL=20290508"
        )
        assert_equal %w[2026-12-31 2028-01-31 2028-03-31 2028-05-31
                        2028-07-31 2028-08-31 2028-10-31 2028-12-31],
                     rule.occurrences(Date.new(2026, 12, 31),
                                      Date.new(2030, 1, 1)).map(&:to_s)
    end

    # -1 and 30 are one day in November, yielded once.
    def test_a_day_named_twice_comes_once
        rule = Schedule::Recurrence.parse(
            "FREQ=YEARLY;BYMONTH=11;BYMONTHDAY=-1,30"
        )
        assert_equal %w[2026-11-30 2027-11-30],
                     rule.occurrences(Date.new(2026, 11, 30),
                                      Date.new(2027, 12, 31)).map(&:to_s)
    end

    def test_prints_back_in_icalendar_form
        text = "FREQ=MONTHLY;INTERVAL=2;BYDAY=-1FR;BYMONTH=1,7;UNTIL=20271231"
        assert_equal text, Schedule::Recurrence.parse(text).to_s
        assert_equal "FREQ=DAILY",
                     Schedule::Recurrence.parse("freq=daily;interval=1").to_s
    end

    # Each refusal for its own reason: a rule refused for another (a
    # missing FREQ) would prove nothing about the part it is about.
    REFUSED = {
        "FREQ=HOURLY" => "FREQ=HOURLY is not supported",
        "FREQ=DAILY;BYSETPOS=1" => "BYSETPOS is not supported",
        "FREQ=WEEKLY;BYDAY=2TU" => "BYDAY ordinals need",
        "FREQ=YEARLY;BYDAY=1MO" => "BYDAY ordinals need",
        "FREQ=WEEKLY;BYDAY=XX" => "bad BYDAY XX",
        "FREQ=DAILY;INTERVAL=-2" => "bad INTERVAL -2",
        "FREQ=DAILY;COUNT=2;UNTIL=20270101" => "UNTIL and COUNT exclude",
        "BYDAY=MO" => "FREQ is required",
        "FREQ=MONTHLY;BYMONTHDAY=0" => "bad BYMONTHDAY 0",
        "FREQ=WEEKLY;WKST=SU" => "WKST other than MO",
        "FREQ=DAILY;UNTIL=x" => "bad UNTIL",
        "FREQ=DAILY;FREQ=WEEKLY" => "FREQ twice"
    }.freeze

    def test_refuses_what_is_not_supported
        REFUSED.each do |text, reason|
            error = assert_raises(Schedule::ParseError, text) do
                Schedule::Recurrence.parse(text)
            end
            assert_includes error.message, reason, text
        end
    end
end
