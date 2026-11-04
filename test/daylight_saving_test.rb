# frozen_string_literal: true

require "test_helper"
require "support"

# A 02:30 transition on the nights clocks change, in Paris: 2026-03-29
# goes from 02:00 to 03:00, 2026-10-25 back from 03:00 to 02:00. What
# is in force and when it next changes are told in real time, so a
# caller polling and a caller sleeping until `until` agree.
class DaylightSavingTest < Minitest::Test
    include ScheduleSupport

    CEST = "+02:00"
    CET  = "+01:00"

    def setup
        @zone = Schedule::Zone.new(
            name: "salon",
            timetable: Schedule::Timetable.new(
                days: (0..6).to_h do |day|
                    [day, program("p", "02:30" => COMFORT, "22:00" => NIGHT)]
                end
            )
        )
    end

    def test_a_transition_in_the_repeated_hour_happens_once
        in_zone("Europe/Paris") do
            first = Time.new(2026, 10, 25, 2, 30, 0, CEST)
            assert_equal [first, "night"], change_at(2026, 10, 25, 2, 15, CEST)
            assert_equal "comfort", label_at(2026, 10, 25, 2, 40, CEST)
            assert_equal "comfort", label_at(2026, 10, 25, 2, 15, CET)
            assert_equal "comfort", label_at(2026, 10, 25, 2, 40, CET)
        end
    end

    def test_a_transition_in_the_missing_hour_happens_at_its_until
        in_zone("Europe/Paris") do
            moved = Time.new(2026, 3, 29, 3, 30, 0, CEST)
            assert_equal [moved, "night"], change_at(2026, 3, 29, 1, 50, CET)
            assert_equal "night", label_at(2026, 3, 29, 3, 10, CEST)
            assert_equal "comfort", label_at(2026, 3, 29, 3, 30, CEST)
        end
    end

    private

    def decision(*moment)
        Schedule::Stack.new([base]).resolve(@zone, Time.new(*moment[0, 5], 0,
                                                            moment[5]))
    end

    def label_at(*moment) = decision(*moment).label

    def change_at(*moment) = decision(*moment).then { [it.until, it.label] }
end
