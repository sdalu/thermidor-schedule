# frozen_string_literal: true

require "test_helper"
require "support"

# A transition's on-time mark: whether the change is wanted reached by
# its time (true) or only started then (false), unmarked the
# default_on_time configured. December 2026: every day runs `work`, the
# 24th a holiday.
class OnTimeTest < Minitest::Test
    include ScheduleSupport

    Syntax = Thermidor::Schedule::Syntax
    BAND   = Schedule::Preset.new(setpoint: Schedule::Setpoint.new(heat: 19))

    def teardown
        Schedule.configure(**Schedule::Config::DEFAULT.to_h)
    end

    def test_a_mark_is_kept
        [true, false].each do |mark|
            [COMFORT, "comfort", BAND].each do |preset|
                assert_equal mark, transition(preset:, on_time: mark).on_time
            end
        end
    end

    # A named preset, its name or an inline band alike: the slot says,
    # never the preset.
    def test_unmarked_takes_the_default_configured
        [true, false].each do |default|
            Schedule.configure(default_on_time: default)
            [COMFORT, "comfort", BAND].each do |preset|
                assert_equal default, transition(preset:).on_time
            end
        end
    end

    # A keyword takes no mark but holds the default, said when it
    # reaches the fallback.
    def test_a_keyword_holds_the_default
        [true, false].each do |default|
            Schedule.configure(default_on_time: default)
            assert_equal default, transition(through: :pass).on_time
        end
    end

    def test_a_keyword_or_another_value_is_refused
        [{ through: :pass, on_time: true }, { through: :usual, on_time: false },
         { preset: COMFORT, on_time: "yes" }].each do |args|
            assert_raises(Schedule::Error, args.inspect) { transition(**args) }
        end
    end

    def test_read_from_text
        { "06:30=comfort/quick:by" => ["comfort", :quick, true],
          "22:00=+17..+27:at" => ["+17.0..+27.0", nil, false],
          "06:30=comfort" => ["comfort", nil, true],
          "22:00=+17..+27" => ["+17.0..+27.0", nil, true] }
            .each do |text, expected|
            found = Syntax.transition(text)
            preset = found.preset
            preset = preset.setpoint.to_s if preset.is_a?(Schedule::Preset)
            assert_equal expected, [preset, found.strategy, found.on_time], text
        end
    end

    def test_text_refused
        %w[22:00=pass:by 06:30=comfort/quick/quiet:by
           06:30=comfort/:by 06:30=:by 06:30=comfort+on-time].each do |text|
            assert_raises(Schedule::ParseError, text) do
                Syntax.transition(text)
            end
        end
    end

    # The strategy and the mark come in either order after the preset.
    def test_the_strategy_and_the_mark_in_either_order
        %w[06:30=comfort/quick:by 06:30=comfort:by/quick].each do |text|
            found = Syntax.transition(text)
            assert_equal ["comfort", :quick, true],
                         [found.preset, found.strategy, found.on_time], text
        end
        found = Syntax.transition("22:00=+17..+27:at/quiet")
        assert_equal [:quiet, false], [found.strategy, found.on_time]
    end

    # Another word, or a mark twice, is named as a bad mark, not read as
    # a preset's name.
    def test_an_unknown_or_repeated_mark_says_so
        %w[06:30=comfort:late 06:30=comfort:by:by 06:30=comfort:at/quick:by
           06:30=comfort:].each do |text|
            error = assert_raises(Schedule::ParseError, text) do
                Syntax.transition(text)
            end
            assert_match(/one :by or :at/, error.message, text)
        end
    end

    # The decision carries the mark of the transition that decided: a
    # holiday's own, the weekday's it lets through, and the default for
    # the fallback a keyword reaches.
    def test_the_decision_carries_the_deciding_mark
        layers = [base, Schedule::Layers::Calendar.new([holiday])]
        marks = %w[09:00 13:00 23:30].map do |clock|
            resolve("2026-12-24 #{clock}", layers:).on_time
        end
        assert_equal [true, false, true], marks
    end

    # Reached through a keyword, the fallback is a change of the program
    # and takes the default configured when the program was built.
    def test_the_fallback_reached_by_a_keyword_takes_the_default
        Schedule.configure(default_on_time: false)
        setup
        found = @zone.timetable.at(at("2026-12-23 23:30"))
        assert_equal [true, false], [found.fallback?, found.on_time]
        assert_equal false, resolve("2026-12-23 23:30").on_time
    end

    # With no program in force at all, there is no change to mark.
    def test_the_fallback_of_no_program_holds_none
        empty = Schedule::Zone.new(name: "attic")
        assert_nil Schedule::Stack.new([base]).resolve(
            empty, at("2026-12-23 23:30")
        ).on_time
    end

    def test_the_resolution_carries_it_too
        found = @zone.timetable.at(at("2026-12-23 07:00"))
        assert_equal [COMFORT, true], [found.preset, found.on_time]
        assert resolve("2026-12-23 07:00").on_time
    end

    def setup
        work = program("work", "06:45" => [COMFORT, nil, true],
                               "08:30" => [ECO, nil, false],
                               "23:00" => :fallback)
        holiday = program("holiday", "08:15" => [COMFORT, nil, true],
                                     "12:00" => :pass)
        timetable = Schedule::Timetable.new(days: (0..6).to_h { [it, work] },
                                            specials: { "holiday" => holiday })
        @zone = Schedule::Zone.new(name: "living", timetable:)
    end

    private

    def transition(**) = Schedule::Transition.new(minute: 390, **)

    def holiday = ScheduleSupport.holiday(Date.new(2026, 12, 24))
end
