# frozen_string_literal: true

require "test_helper"

# What the text forms refuse rather than read loosely: an empty piece of
# a list, weekdays as a kind of day, years in any form but four digits.
class SyntaxRefusalsTest < Minitest::Test
    Schedule = Thermidor::Schedule
    Syntax   = Schedule::Syntax

    # An empty piece of a list is refused, at either end or in between,
    # never read as a day (nil) or skipped.
    def test_an_empty_piece_of_a_list_is_refused
        [",mon", "mon,,tue", "mon,"].each do |text|
            assert_raises(Schedule::ParseError, text) { Syntax.days(text) }
        end
        [",06:30=comfort", "06:30=comfort,,07:00=eco", "06:30=comfort,"]
            .each do |text|
                assert_raises(Schedule::ParseError, text) do
                    Syntax.program(text)
                end
            end
    end

    # Weekdays written as a range or a list are no kind of day: the
    # same text would name a special day here and weekdays elsewhere.
    def test_weekdays_are_no_special_day
        %w[mon-fri sat-sun].each do |text|
            assert_raises(Schedule::ParseError, text) { Syntax.day_kind(text) }
        end
        assert_equal "mon", Syntax.day_kind("Monday")
    end

    # Years are four digits, alone or as a range: nothing else is read.
    def test_years_are_four_digits
        assert_equal 2027..2029, Syntax.years("2027..2029")
        [" 2027 ", "2_027", "+2027", "02027", "2027 ..2029", "27"]
            .each do |text|
                assert_raises(Schedule::ParseError, text.inspect) do
                    Syntax.years(text)
                end
            end
    end
end
