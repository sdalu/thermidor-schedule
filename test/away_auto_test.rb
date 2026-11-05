# frozen_string_literal: true

require "test_helper"
require "support"

# The away layer's automatic period, from `auto_since`. 2026-11-02 is a
# Monday.
class AwayAutoTest < Minitest::Test
    include ScheduleSupport

    Entry = Schedule::Layers::Away::Entry

    def setup
        @zone = workday_zone
    end

    def test_holds_the_default_until_presence_changes
        decision = resolve("2026-11-02 10:00",
                           layers: away(since: at("2026-11-02 09:00")))
        assert_equal ["away", "away:auto", nil],
                     decision.to_h.values_at(:label, :source, :until)
    end

    def test_from_the_moment_it_starts
        layers = away(since: at("2026-11-02 09:00"))
        sources = ["2026-11-02 08:59", "2026-11-02 09:00"]
                  .map { resolve(it, layers:).source }
        assert_equal %w[timetable:workday away:auto], sources
    end

    def test_one_still_to_start_brings_the_change_forward
        decision = resolve("2026-11-02 09:00",
                           layers: away(since: at("2026-11-02 10:00")))
        assert_equal ["eco", "timetable:workday", at("2026-11-02 10:00")],
                     decision.to_h.values_at(:label, :source, :until)
    end

    def test_a_later_change_below_is_left_alone
        decision = resolve("2026-11-02 08:00",
                           layers: away(since: at("2026-11-02 10:00")))
        assert_equal at("2026-11-02 08:30"), decision.until
    end

    def test_an_entry_beats_it
        entry = Entry.new("salon", ECO, at("2026-11-02 09:30"),
                          at("2026-11-02 11:00"))
        layers = away(entry, since: at("2026-11-02 09:00"))
        decision = resolve("2026-11-02 10:00", layers:)
        assert_equal ["eco", "away", at("2026-11-02 11:00")],
                     decision.to_h.values_at(:label, :source, :until)
        assert_equal "away:auto", resolve("2026-11-02 11:00", layers:).source
    end

    def test_an_entry_for_another_zone_does_not
        entry = Entry.new("office", ECO, at("2026-11-02 09:30"), nil)
        layers = away(entry, since: at("2026-11-02 09:00"))
        assert_equal "away:auto", resolve("2026-11-02 10:00", layers:).source
    end

    private

    def away(*entries, since:)
        [base, Schedule::Layers::Away.new(entries, auto_since: since)]
    end
end
