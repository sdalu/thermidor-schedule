# frozen_string_literal: true

require "test_helper"
require "support"

# When a manual setting, boost or open window ends, fixed when it is
# made. 2026-11-02 is a Monday; 2026-11-11 a holiday.
class ManualEndsTest < Minitest::Test
    include ScheduleSupport

    def setup
        @zone = workday_zone
    end

    HOLIDAY = Schedule::Layers::Calendar::Entry.new(
        id: 1, calendar: "fr", priority: 8, zone: nil, kind: "holiday",
        first: Date.new(2026, 11, 11), last: Date.new(2026, 11, 11),
        description: nil
    )

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

    def test_boosts_and_open_windows_always_end_on_their_own
        [Schedule::Layers::Boost, Schedule::Layers::OpenWindow].each do |kind|
            %i[forever next].each do |mode|
                error = assert_raises(ArgumentError, "#{kind} #{mode}") do
                    kind.ends_at(mode, below: stack, zone: @zone,
                                       now: at("2026-11-02 10:00"))
                end
                assert_match(/\b#{mode}\b/, error.message)
            end
        end
    end

    def test_boosts_and_open_windows_still_take_a_duration
        [Schedule::Layers::Boost, Schedule::Layers::OpenWindow].each do |kind|
            assert_equal at("2026-11-02 10:30"),
                         kind.ends_at(:for, below: stack, zone: @zone,
                                            now: at("2026-11-02 10:00"),
                                            duration: 1800)
        end
    end

    # The eve of a holiday whose program starts at 09:00: the calendar
    # hides the timetable's 06:30, so :next ends at 09:00.
    def test_next_on_a_holiday_eve_ends_at_the_holiday_change
        @zone = @zone.with(timetable: @zone.timetable.with(
            specials: { "holiday" => program("holiday", "09:00" => COMFORT) }
        ))
        below = Schedule::Stack.new([base, Schedule::Layers::Calendar.new(
            [HOLIDAY]
        )])
        assert_equal at("2026-11-11 09:00"),
                     Schedule::Layers::Manual.ends_at(
                         :next, below:, zone: @zone, now: at("2026-11-10 23:00")
                     )
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

    def stack = Schedule::Stack.new([base])

    # The end of a setting made on a Monday at 10:00, on the workday zone.
    def ends(mode, **)
        Schedule::Layers::Manual.ends_at(
            mode, below: Schedule::Stack.new([base]), zone: @zone,
                  now: at("2026-11-02 10:00"), **
        )
    end
end
