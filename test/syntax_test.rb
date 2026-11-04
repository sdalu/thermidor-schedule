# frozen_string_literal: true

require "test_helper"

class SyntaxTest < Minitest::Test
    Schedule = Thermidor::Schedule
    Syntax   = Schedule::Syntax

    def test_names_stay_references
        assert_equal ["comfort", nil], Syntax.preset_ref("comfort")
        assert_equal ["comfort", :quick], Syntax.preset_ref("comfort/quick")
    end

    def test_bands_become_anonymous_presets
        preset, strategy = Syntax.preset_ref("+20.5..+25/quick")
        assert_predicate preset, :anonymous?
        assert_equal [20.5, 25.0], [preset.setpoint.heat, preset.setpoint.cool]
        assert_equal :quick, strategy
    end

    def test_open_bands_and_off
        assert_equal "+5.0..", Syntax.preset("+5..").setpoint.to_s
        assert_equal "..+26.0", Syntax.preset("..+26").setpoint.to_s
        assert_equal "-5.0..", Syntax.preset("-5..").setpoint.to_s
        assert_predicate Syntax.preset("off").setpoint, :off?
    end

    def test_rejects_bad_bands
        %w[+20.5..25 20..+25 .. +20.55..+25 +20.5-+25].each do |text|
            assert_raises(Schedule::ParseError, text) { Syntax.preset(text) }
        end
        assert_raises(Schedule::Error) { Syntax.preset("+20.5..-10") }
    end

    def test_rejects_bad_names_and_strategies
        assert_raises(Schedule::ParseError) { Syntax.preset_ref("Comfort") }
        assert_raises(Schedule::ParseError) { Syntax.preset_ref("eco/loud") }
        assert_raises(Schedule::ParseError) { Syntax.preset_ref("eco/x/y") }
    end

    def test_transitions
        transition = Syntax.transition("06:30=comfort/quick")
        assert_equal [390, "comfort", :quick],
                     [transition.minute, transition.preset, transition.strategy]
        %w[24:00=eco 06:60=eco 0630=eco 06:30].each do |text|
            assert_raises(Schedule::ParseError, text) do
                Syntax.transition(text)
            end
        end
    end

    def test_inline_programs
        program = Syntax.program("23:00=+19..,07:00=comfort")
        assert_predicate program.name, :nil?
        assert_equal [420, 1380], program.transitions.map(&:minute)
        assert_equal "workday", Syntax.program("workday")
    end

    def test_days
        assert_equal [1, 2, 3, 4, 5], Syntax.days("mon-fri")
        assert_equal [6, 0], Syntax.days("sat,sun")
        assert_equal [5, 6, 0, 1], Syntax.days("fri-mon")
        assert_equal [3], Syntax.days("Wednesday")
        assert_raises(Schedule::ParseError) { Syntax.days("xyz") }
    end

    def test_weekdays_are_whole_names_only
        assert_equal [6], Syntax.days("saturday")
        assert_raises(Schedule::ParseError) { Syntax.days("satellite") }
    end

    def test_day_keys_are_weekdays_or_a_special_day
        assert_equal [1, 2, 3, 4, 5], Syntax.day_keys("mon-fri")
        assert_equal ["holiday"], Syntax.day_keys("holiday")
        assert_equal ["bank-holiday"], Syntax.day_keys("bank-holiday")
        assert_raises(Schedule::ParseError) { Syntax.day_keys("Holiday") }
    end

    def test_day_kinds
        assert_equal "sun", Syntax.day_kind("Sunday")
        assert_equal "holiday", Syntax.day_kind("holiday")
    end

    def test_dates
        assert_equal [Date.new(2026, 12, 25)] * 2, Syntax.dates("2026-12-25")
        assert_equal [Date.new(2026, 12, 24), Date.new(2026, 12, 26)],
                     Syntax.dates("2026-12-24..2026-12-26")
        %w[2026-12-26..2026-12-24 2026-13-01 25/12].each do |text|
            assert_raises(Schedule::ParseError, text) { Syntax.dates(text) }
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
end
