# frozen_string_literal: true

require "test_helper"
require "support"

# A guard suspended by some layers: set aside while the decision below
# comes from one of them and has an end, named in Decision#suspended. The
# bedroom: frost and bamboo-floor always, bamboo-ceiling suspended by a
# manual setting or a boost. 2026-11-02 is a Monday.
class GuardSuspensionTest < Minitest::Test
    include ScheduleSupport

    Guard  = Schedule::Layers::Guard
    Manual = Schedule::Layers::Manual
    DAY = Schedule::Preset.new(name: "day",
                               setpoint: Schedule::Syntax.band("+20..+24"))

    def setup
        days = (0..6).to_h { [it, program("day", "06:30" => DAY)] }
        @zone = Schedule::Zone.new(name: "bedroom",
                                   timetable: Schedule::Timetable.new(days:))
    end

    def test_the_timetable_alone_suspends_nothing
        decision = at_two(guard_layer)
        assert_equal ["+20.0..+24.0", {}], seen(decision)
    end

    # A 30-minute boost gets its 28: the ceiling waits for its end.
    def test_a_boost_suspends_the_ceiling_while_it_lasts
        boost = Schedule::Layers::Boost.new([entry("+28..", minutes: 30)])
        assert_equal ["+28.0..", { "bamboo-ceiling" => "boost" }],
                     seen(at_two(boost, guard_layer))
    end

    # Off for two hours: free to stop cooling, still held at the floor.
    def test_a_manual_setting_with_an_end_keeps_the_others
        decision = at_two(Manual.new([entry("off", minutes: 120)]),
                          guard_layer)
        assert_equal ["+15.0..", { "bamboo-ceiling" => "manual" }],
                     seen(decision)
        assert_equal({ heat: "bamboo-floor", humidity_low: "bamboo-floor" },
                     decision.guards)
    end

    # No end, no suspension: forever +28 is held under the ceiling.
    def test_a_setting_with_no_end_suspends_nothing
        decision = at_two(Manual.new([entry("+28..")]), guard_layer)
        assert_equal ["+24.0..+25.0", {}], seen(decision)
        assert_equal({ heat: "bamboo-ceiling", cool: "bamboo-ceiling",
                       humidity_low: "bamboo-floor",
                       humidity_high: "bamboo-ceiling" }, decision.guards)
    end

    # An entry queued after a forever one, in its layer or one above,
    # brings `until` forward but gives it no end: it may come back.
    def test_a_queued_entry_gives_no_end_to_a_forever_setting
        later = entry("+20..", minutes: 30, from: "2026-11-02 18:00")
        forever = Manual.new([entry("+28..")])
        [[Manual.new([entry("+28.."), later])],
         [forever, Schedule::Layers::Boost.new([later])],
         [forever, Schedule::Layers::OpenWindow.new([later])]].each do |layers|
            assert_equal ["+24.0..+25.0", {}],
                         seen(at_two(*layers, guard_layer)), layers.last.class
        end
    end

    # Away for a dated while has an end; automatic away has none.
    def test_away_with_an_end_suspends
        away = Schedule::Layers::Away.new([Schedule::Layers::Away::Entry.new(
            zone: "bedroom", preset: Schedule::Syntax.preset("+28.."),
            starts_at: at("2026-11-02 09:00"), ends_at: at("2026-11-03 09:00")
        )])
        assert_equal ["+28.0..", { "bamboo-ceiling" => "away" }],
                     seen(at_two(away, guard_layer(%w[away])))
        auto = Schedule::Layers::Away.new([],
                                          auto_since: at("2026-11-02 09:00"))
        assert_empty at_two(auto, guard_layer(%w[away])).suspended
    end

    # A layer not listed suspends nothing; one listed does.
    def test_only_the_layers_listed_suspend
        window = Schedule::Layers::OpenWindow.new([entry(nil, minutes: 15)])
        assert_equal ["+15.0..+25.0", {}], seen(at_two(window, guard_layer))
        layer = guard_layer(%w[manual boost open-window])
        assert_equal ["+15.0..", { "bamboo-ceiling" => "open-window" }],
                     seen(at_two(window, layer))
    end

    def test_stacked_guard_layers_add_to_the_suspended
        frost = Guard.new([guard("frost", "+7..",
                                 suspended_by: %w[boost])])
        boost = Schedule::Layers::Boost.new([entry("+28..", minutes: 30)])
        decision = at_two(boost, frost, guard_layer)
        assert_equal({ "frost" => "boost", "bamboo-ceiling" => "boost" },
                     decision.suspended)
    end

    # The whole set is checked, the suspended included.
    def test_a_suspended_guard_still_counts_when_built
        assert_raises(Schedule::Error) do
            Guard.new([guard("warm", "+24.6.."),
                       guard("cap", "..+25", suspended_by: %w[boost])])
        end
        %w[Boost calendar:fr].push(:boost, "").each do |layer|
            assert_raises(Schedule::Error, layer.inspect) do
                guard("cap", "..+25", suspended_by: [layer])
            end
        end
    end

    private

    def seen(decision)
        [decision.setpoint.to_s.split("@").first, decision.suspended]
    end

    def guard_layer(ceiling_by = %w[manual boost])
        Guard.new([guard("frost", "+7.."),
                   guard("bamboo-floor", "+15..@40.."),
                   guard("bamboo-ceiling", "..+25@..65",
                         suspended_by: ceiling_by)])
    end

    def guard(name, text, suspended_by: [])
        Guard::Entry.new(zone: "bedroom", name:, suspended_by:,
                         bounds: Schedule::Syntax.guard(text))
    end

    # A setting made at `from`, for `minutes` (nil: forever).
    def entry(band, minutes: nil, from: "2026-11-02 13:55")
        starts_at = at(from)
        Manual::Entry.new(zone: "bedroom", strategy: nil,
                          preset: band && Schedule::Syntax.preset(band),
                          starts_at:,
                          ends_at: minutes && (starts_at + (minutes * 60)),
                          mode: minutes ? :for : :forever)
    end

    def at_two(*layers)
        resolve("2026-11-02 14:00", layers: [base, *layers])
    end
end
