# frozen_string_literal: true

require "test_helper"

# The text forms of years, dates, times and durations (syntax/time.rb).
class SyntaxTimeTest < Minitest::Test
    Schedule = Thermidor::Schedule
    Syntax   = Schedule::Syntax

    def test_dates
        assert_equal [Date.new(2026, 12, 25)] * 2, Syntax.dates("2026-12-25")
        assert_equal [Date.new(2026, 12, 24), Date.new(2026, 12, 26)],
                     Syntax.dates("2026-12-24..2026-12-26")
        %w[2026-12-26..2026-12-24 2026-13-01 25/12].each do |text|
            assert_raises(Schedule::ParseError, text) { Syntax.dates(text) }
        end
    end

    def test_years
        assert_equal 2027..2027, Syntax.years("2027")
        assert_equal 2027..2029, Syntax.years("2027..2029")
        error = assert_raises(Schedule::ParseError) do
            Syntax.years("2029..2027")
        end
        assert_match(/ends before it starts/, error.message)
        %w[20x7 2027.. ..2027].each do |text|
            assert_raises(Schedule::ParseError, text) { Syntax.years(text) }
        end
    end

    def test_durations
        seconds = %w[2h 90m 1h30 30 0].map { Syntax.duration(it) }
        assert_equal [7200, 5400, 5400, 1800, 0], seconds
        %w[h 1.5h 2d 1h30x].each do |text|
            assert_raises(Schedule::ParseError, text) { Syntax.duration(text) }
        end
    end

    def test_times
        now = Time.new(2026, 11, 2, 15, 0)
        assert_equal Time.new(2026, 11, 2, 7, 0), Syntax.time("07:00", now)
        assert_equal Time.new(2026, 12, 24, 18, 30),
                     Syntax.time("2026-12-24 18:30", now)
        assert_raises(Schedule::ParseError) do
            Syntax.time("2026-13-01 10:00", now)
        end
    end

    def test_a_time_ahead_is_never_in_the_past
        now = Time.new(2026, 11, 2, 15, 0)
        assert_equal Time.new(2026, 11, 3, 7, 0),
                     Syntax.time("07:00", now, ahead: true)
        assert_equal Time.new(2026, 11, 3, 15, 0),
                     Syntax.time("15:00", now, ahead: true)
        assert_equal Time.new(2026, 11, 2, 15, 1),
                     Syntax.time("15:01", now, ahead: true)
    end

    def test_ahead_leaves_a_dated_time_alone
        now = Time.new(2026, 11, 2, 15, 0)
        assert_equal Time.new(2026, 11, 1, 7, 0),
                     Syntax.time("2026-11-01 07:00", now, ahead: true)
        assert_equal Time.new(2026, 11, 2, 7, 0),
                     Syntax.time("2026-11-02 07:00", now, ahead: true)
    end
end
