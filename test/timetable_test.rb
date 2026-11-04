# frozen_string_literal: true

require "test_helper"
require "support"

# 2026-11-02 is a Monday, 2026-11-01 a Sunday.
class TimetableTest < Minitest::Test
    include ScheduleSupport

    def setup
        @workday = program("workday", "06:30" => [COMFORT, :quick],
                                      "08:30" => ECO, "22:30" => NIGHT)
        @weekend = program("weekend", "09:00" => COMFORT, "23:30" => NIGHT)
        days = (1..5).to_h { [it, @workday] }
        days.merge!(6 => @weekend, 0 => @weekend)
        @timetable = Schedule::Timetable.new(days:)
    end

    def test_in_force_within_a_day
        entry = @timetable.at(at("2026-11-02 07:00"))
        assert_equal [@workday, 390], [entry.program, entry.transition.minute]
        assert_equal :quick, entry.transition.strategy
        assert_equal ECO, @timetable.at(at("2026-11-02 08:30"))
                                    .transition.preset
    end

    def test_before_the_first_transition_carries_on_from_yesterday
        entry = @timetable.at(at("2026-11-02 05:00"))
        assert_equal [@weekend, NIGHT], [entry.program, entry.transition.preset]
    end

    def test_sunday_wraps_to_monday_and_back
        assert_equal NIGHT, @timetable.at(at("2026-11-01 08:00"))
                                      .transition.preset
        assert_equal at("2026-11-02 06:30"),
                     @timetable.next_change(at("2026-11-01 23:45"))
    end

    def test_usual_binds_a_special_day_only
        usual = Schedule::Timetable::USUAL
        timetable = Schedule::Timetable.new(specials: { "leave" => usual })
        assert_same usual, timetable.program_for("leave")
        error = assert_raises(Schedule::Error) do
            Schedule::Timetable.new(days: { 1 => usual })
        end
        assert_match(/usual.*special day/, error.message)
    end

    def test_days_without_a_program_carry_on
        timetable = Schedule::Timetable.new(days: { 3 => @workday })
        entry = timetable.at(at("2026-11-02 12:00"))
        assert_equal NIGHT, entry.transition.preset
        assert_equal at("2026-11-04 06:30"),
                     timetable.next_change(at("2026-11-02 12:00"))
    end

    def test_a_single_transition_lasts_all_week
        timetable = Schedule::Timetable.new(
            days: { 3 => program("once", "12:00" => ECO) }
        )
        assert_equal ECO, timetable.at(at("2026-11-04 11:00")).transition.preset
        assert_equal at("2026-11-04 12:00"),
                     timetable.next_change(at("2026-11-04 11:00"))
        assert_equal at("2026-11-11 12:00"),
                     timetable.next_change(at("2026-11-04 12:00"))
    end

    def test_entry_tells_which_date_it_ran_on
        entry = @timetable.at(at("2026-11-02 05:00"))
        assert_equal Date.new(2026, 11, 1), entry.date
    end

    def test_program_for_a_weekday_or_special_day
        timetable = @timetable.with(specials: { "holiday" => @weekend })
        assert_equal @workday, timetable.program_for("mon")
        assert_equal @weekend, timetable.program_for("holiday")
        assert_nil timetable.program_for("bank-holiday")
    end

    def test_empty_timetable
        timetable = Schedule::Timetable.new
        assert_nil timetable.at(at("2026-11-02 12:00"))
        assert_nil timetable.next_change(at("2026-11-02 12:00"))
        assert_predicate timetable, :empty?
    end

    def test_next_change_within_and_across_days
        assert_equal at("2026-11-02 08:30"),
                     @timetable.next_change(at("2026-11-02 06:30"))
        assert_equal at("2026-11-03 06:30"),
                     @timetable.next_change(at("2026-11-02 22:30"))
    end

    def test_next_change_across_daylight_saving
        in_zone("Europe/Paris") do
            night = program("night", "02:30" => NIGHT, "07:00" => COMFORT)
            timetable = Schedule::Timetable.new(days: { 0 => night })
            # 2026-03-29: clocks go from 02:00 to 03:00, so 02:30 never
            # comes; it happens when they jump, 60 real minutes on.
            change = timetable.next_change(Time.new(2026, 3, 29, 1, 0))
            assert_equal Time.new(2026, 3, 29, 3, 0), change
            assert_equal 60 * 60, change - Time.new(2026, 3, 29, 1, 0)
            # 2026-10-25: clocks go back from 03:00 to 02:00; the first
            # 02:30, summer time's.
            change = timetable.next_change(Time.new(2026, 10, 25, 0, 0))
            assert_equal Time.new(2026, 10, 25, 2, 30, 0, "+02:00"), change
        end
    end

    def test_programs_reject_two_transitions_at_once
        assert_raises(Schedule::Error) do
            program("bad", "06:30" => ECO).then do |one|
                Schedule::Program.new(transitions: one.transitions * 2)
            end
        end
    end
end
