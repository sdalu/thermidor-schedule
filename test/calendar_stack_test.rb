# frozen_string_literal: true

require "test_helper"
require "support"

# Calendar programs that let another through (pass, usual, fallback), and
# the entries of a date stacked. December 2026: the 23rd a Wednesday, the
# 24th a Thursday, the 25th a Friday; every weekday runs `work`.
class CalendarStackTest < Minitest::Test
    include ScheduleSupport

    DAY = Date.new(2026, 12, 24)

    def setup
        @work = program("work", "06:45" => COMFORT, "08:30" => ECO,
                                "23:00" => NIGHT)
    end

    def test_pass_lets_the_weekday_program_through
        zone = zone_with({ "holiday" => special("08:15" => COMFORT,
                                                "12:00" => :pass) })
        decision = resolve("2026-12-24 13:00", zone:, layers: on(holiday))
        assert_equal ["eco", "timetable:work", at("2026-12-24 23:00")],
                     decision.to_h.values_at(:label, :source, :until)
    end

    # A keyword carried past midnight falls into the next date's stack,
    # whose weekday program answers alone: it carries its own night on.
    def test_a_carried_pass_reaches_the_weekday_s_own_night
        zone = zone_with({ "holiday" => special("10:00" => COMFORT,
                                                "23:30" => :pass) })
        layers = on(holiday)
        decision = resolve("2026-12-25 03:00", zone:, layers:)
        assert_equal ["night", "timetable:work", at("2026-12-25 06:45")],
                     decision.to_h.values_at(:label, :source, :until)
        assert_equal at("2026-12-25 06:45"),
                     resolve("2026-12-24 23:40", zone:, layers:).until
    end

    def test_carried_usual_and_default
        { usual: %w[night timetable:work], fallback: %w[frost fallback] }
            .each do |word, expected|
                zone = zone_with({ "holiday" => special("10:00" => COMFORT,
                                                        "23:30" => word) })
                decision = resolve("2026-12-25 03:00", zone:,
                                                       layers: on(holiday))
                assert_equal expected, decision.to_h.values_at(:label, :source)
            end
    end

    # The weekday's pass (the fallback, at that level) carried into a
    # holiday that has said nothing yet: the holiday's stack answers.
    def test_a_weekday_pass_carried_into_a_holiday_morning
        work = special({ "06:30" => COMFORT, "22:00" => :pass }, "work")
        zone = zone_with({ "holiday" => special("08:00" => ECO) }, work:)
        layers = on(holiday)
        assert_equal %w[frost fallback], label_source("03:00", zone, layers)
        assert_equal %w[comfort timetable:work],
                     label_source("07:00", zone, layers)
        assert_equal %w[eco calendar:fr:holiday],
                     label_source("09:00", zone, layers)
    end

    def test_three_calendars_stacked
        guest = special("07:00" => :pass, "18:00" => COMFORT)
        leave = special("07:00" => :pass)
        zone = zone_with({ "leave" => leave, "guest" => guest,
                           "holiday" => special("07:00" => NIGHT) })
        layers = on(holiday, entry(2, "guest", 5), entry(3, "leave", 3))
        assert_equal %w[night calendar:fr:holiday],
                     label_source("12:00", zone, layers)
        assert_equal %w[comfort calendar:guest:guest],
                     label_source("19:00", zone, layers)
    end

    def test_usual_and_default_skip_the_calendars_below
        { usual: %w[eco timetable:work], fallback: %w[frost fallback] }
            .each do |word, expected|
                zone = zone_with({ "leave" => special("07:00" => word),
                                   "holiday" => special("07:00" => NIGHT) })
                layers = on(holiday, entry(3, "leave", 3))
                assert_equal expected, label_source("12:00", zone, layers)
            end
    end

    def test_the_calendar_takes_its_fallback
        zone = zone_with({ "holiday" => special("07:00" => :fallback) })
        away = Schedule::Preset.away
        layers = [base, Schedule::Layers::Calendar.new([holiday],
                                                       fallback: away)]
        assert_equal %w[away fallback], label_source("12:00", zone, layers)
    end

    # An entry left out of a date by one bound to usual still covers it:
    # reached through a keyword later, it carries on from what its own
    # program said there. Leave (3, usual in this zone) holds the 23rd;
    # the guest day (5) covers the 22nd to the 24th.
    def test_an_entry_left_out_by_usual_still_carries_on
        zone = zone_with({ "guest" => special("08:00" => :pass,
                                              "18:00" => COMFORT),
                           "leave" => Schedule::Timetable::USUAL },
                         work: special({ "06:30" => COMFORT,
                                         "22:00" => :pass }, "work"))
        guest = entry(2, "guest", 5).with(first: DAY - 2)
        leave = entry(3, "leave", 3).with(first: DAY - 1, last: DAY - 1)
        assert_equal %w[comfort calendar:guest:guest],
                     label_source("03:00", zone, on(guest, leave))
    end

    private

    def label_source(clock, zone, layers)
        resolve("2026-12-24 #{clock}", zone:, layers:)
            .to_h.values_at(:label, :source)
    end

    # A special day's program: "HH:MM" => a preset or a keyword.
    def special(steps, name = nil) = program(name, steps)

    def zone_with(specials, work: @work)
        days = (0..6).to_h { [it, work] }
        timetable = Schedule::Timetable.new(days:, specials:)
        Schedule::Zone.new(name: "living", timetable:)
    end

    def holiday = ScheduleSupport.holiday(DAY)

    def entry(id, kind, priority)
        holiday.with(id:, calendar: kind, kind:, priority:)
    end

    def on(*entries) = [base, Schedule::Layers::Calendar.new(entries)]
end
