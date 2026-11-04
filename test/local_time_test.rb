# frozen_string_literal: true

require "test_helper"
require "support"

# A Time given in another offset (UTC) is the same moment: the dates
# and clock readings are taken in local time. In Paris, 23:30 UTC on
# Wednesday 2026-11-04 is 00:30 on Thursday.
class LocalTimeTest < Minitest::Test
    include ScheduleSupport

    UTC = Time.utc(2026, 11, 4, 23, 30)

    def test_the_program_is_the_local_days
        in_zone("Europe/Paris") do
            days = (0..6).to_h do |day|
                [day, program("d#{day}", "00:15" => COMFORT)]
            end
            timetable = Schedule::Timetable.new(days:)
            assert_equal "d4", timetable.at(UTC).program.name
            assert_equal Time.new(2026, 11, 6, 0, 15),
                         timetable.next_change(UTC)
        end
    end

    def test_a_clock_time_is_on_the_local_day
        in_zone("Europe/Paris") do
            assert_equal Time.new(2026, 11, 5, 7, 0),
                         Schedule::Syntax.time("07:00", UTC)
        end
    end
end
