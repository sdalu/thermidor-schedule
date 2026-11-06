# frozen_string_literal: true

require "test_helper"
require "support"

# A guest room that runs only on holidays, no weekday program: what the
# calendar must announce, the timetable below having nothing to say.
class CalendarGuestTest < Minitest::Test
    include ScheduleSupport

    CHRISTMAS = ScheduleSupport.holiday(Date.new(2026, 12, 24),
                                        Date.new(2026, 12, 25))

    def test_a_coming_special_day_is_announced_to_a_zone_without_weekdays
        guest  = guest_room
        layers = calendar(CHRISTMAS)
        assert_equal at("2026-12-24 08:15"),
                     resolve("2026-12-23 12:00", zone: guest, layers:).until
        assert_equal "comfort",
                     resolve("2026-12-24 08:15", zone: guest, layers:).label
    end

    # Its holiday carries on until the timetable's week-long look back
    # no longer sees it: midnight, eight dates after the last.
    def test_the_end_of_a_carried_on_special_day_is_announced
        guest  = guest_room
        layers = calendar(CHRISTMAS)
        stack  = Schedule::Stack.new(layers)
        assert_equal at("2027-01-02 00:00"),
                     stack.wake_at(guest, at("2026-12-27 12:00"))
        refute_equal resolve("2027-01-01 23:50", zone: guest, layers:).label,
                     resolve("2027-01-02 00:00", zone: guest, layers:).label
    end

    private

    def holiday = program("holiday", "08:15" => COMFORT)

    def guest_room
        Schedule::Zone.new(name: "guest", timetable: Schedule::Timetable.new(
            specials: { "holiday" => holiday }
        ))
    end

    def calendar(*entries) = [base, Schedule::Layers::Calendar.new(entries)]
end
