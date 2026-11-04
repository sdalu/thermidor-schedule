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

    private

    def manual(*entries) = [base, Schedule::Layers::Manual.new(entries)]

    def entry(**changes)
        Entry.new(zone: "salon", preset: NIGHT, strategy: nil,
                  starts_at: at("2026-11-02 09:00"),
                  ends_at: at("2026-11-02 12:00"), mode: :for, **changes)
    end
end
