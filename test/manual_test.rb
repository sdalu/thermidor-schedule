# frozen_string_literal: true

require "test_helper"
require "support"

# The manual layer. 2026-11-02 is a Monday.
class ManualTest < Minitest::Test
    include ScheduleSupport

    Entry = Schedule::Layers::Manual::Entry

    def setup
        @zone = workday_zone
    end

    def test_holds_its_preset_until_it_ends
        layers = manual(entry(ends_at: at("2026-11-02 10:30")))
        decision = resolve("2026-11-02 10:00", layers:)
        assert_equal ["night", "manual", at("2026-11-02 10:30")],
                     decision.to_h.values_at(:label, :source, :until)
        assert_equal "timetable:workday",
                     resolve("2026-11-02 10:30", layers:).source
    end

    def test_a_strategy_of_its_own
        layers = manual(entry(strategy: :quick))
        assert_equal :quick, resolve("2026-11-02 10:00", layers:).strategy
    end

    def test_forever_and_other_zones
        layers = manual(entry(zone: "office"), entry(ends_at: nil))
        decision = resolve("2026-12-25 10:00", layers:)
        assert_equal ["manual", nil], decision.to_h.values_at(:source, :until)
        office = Schedule::Zone.new(name: "office", timetable: @zone.timetable)
        assert_equal "manual", resolve("2026-11-02 10:00", zone: office,
                                                           layers:).source
    end

    def test_the_latest_setting_wins
        later = entry(preset: COMFORT, starts_at: at("2026-11-02 09:30"))
        layers = manual(entry, later)
        assert_equal "comfort", resolve("2026-11-02 10:00", layers:).label
    end

    # A later entry takes over when it starts: listed after the one
    # running, or with none running.
    def test_a_setting_still_to_start_is_a_change_ahead
        decision = resolve("2026-11-02 10:00", layers: manual(later))
        assert_equal ["eco", at("2026-11-02 11:00")],
                     decision.to_h.values_at(:label, :until)
    end

    def test_only_a_setting_listed_later_takes_over
        assert_equal at("2026-11-02 11:00"), until_at(entry, later)
        assert_equal at("2026-11-02 12:00"), until_at(later, entry)
    end

    def test_refuses_an_entry_with_no_band_to_hold
        error = assert_raises(Schedule::Error) do
            Schedule::Layers::Manual.new([entry(preset: nil)])
        end
        assert_match(/salon.*no preset/, error.message)
    end

    def test_an_entry_without_a_preset_holds_the_default
        layers = [base, Schedule::Layers::Manual.new([entry(preset: nil)],
                                                     default: COMFORT)]
        assert_equal "comfort", resolve("2026-11-02 10:00", layers:).label
    end

    def test_boosts_and_open_windows_always_have_a_default
        [Schedule::Layers::Boost, Schedule::Layers::OpenWindow].each do |kind|
            layers = [base, kind.new([entry(preset: nil, mode: :heat)])]
            refute_nil resolve("2026-11-02 10:00", layers:).label, kind
        end
    end

    # A duration each kind refuses, and how it says so.
    TOO_LONG = [
        [Schedule::Layers::Manual, (12 * 3600) + 1,
         "a manual setting lasts 0 to 12 hours"],
        [Schedule::Layers::Boost, 3601, "a boost lasts 0 to 1 hour"],
        [Schedule::Layers::OpenWindow, -1, "an open window lasts 0 to 2 hours"]
    ].freeze

    def test_each_kind_says_how_long_it_may_last
        Schedule::Layers::Manual.check_duration(12 * 3600)
        TOO_LONG.each do |kind, seconds, said|
            error = assert_raises(Schedule::Error, said) do
                kind.check_duration(seconds)
            end
            assert_equal said, error.message
        end
    end

    def test_an_end_is_fixed_when_the_setting_is_made
        assert_equal at("2026-11-02 11:30"), ends(:for, duration: 5400)
        assert_equal at("2026-11-02 22:30"), ends(:next)
        assert_nil ends(:forever)
        assert_raises(Schedule::Error) { ends(:for, duration: 13 * 3600) }
        assert_raises(Schedule::Error) { ends(:later) }
    end

    def test_next_without_a_change_below_lasts_the_longest
        empty = Schedule::Zone.new(name: "attic")
        now   = at("2026-11-02 10:00")
        ends  = Schedule::Layers::Manual.ends_at(
            :next, below: Schedule::Stack.new([base]), zone: empty, now:
        )
        assert_equal now + Schedule::Layers::Manual::LONGEST, ends
    end

    private

    def later = entry(preset: COMFORT, starts_at: at("2026-11-02 11:00"))

    def until_at(*entries)
        resolve("2026-11-02 10:00", layers: manual(*entries)).until
    end

    # The end of a setting made on a Monday at 10:00, on the workday zone.
    def ends(mode, **)
        Schedule::Layers::Manual.ends_at(
            mode, below: Schedule::Stack.new([base]), zone: @zone,
                  now: at("2026-11-02 10:00"), **
        )
    end

    def manual(*entries) = [base, Schedule::Layers::Manual.new(entries)]

    def entry(**changes)
        Entry.new(zone: "salon", preset: NIGHT, strategy: nil,
                  starts_at: at("2026-11-02 09:00"),
                  ends_at: at("2026-11-02 12:00"), mode: :for, **changes)
    end
end
