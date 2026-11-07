# frozen_string_literal: true

require "test_helper"
require "support"

# A humidity bound in force: a layer whose preset gives none keeps the
# bound of the decision below and who gave it; one that gives "@" clears
# it. The timetable and the calendar decide afresh. 2026-11-02 is a
# Monday; 2026-12-25 a Friday given as a holiday.
class HumidityLayersTest < Minitest::Test
    include ScheduleSupport

    Manual = Schedule::Layers::Manual
    DAY = Schedule::Preset.new(name: "day",
                               setpoint: Schedule::Syntax.band("+20..+26@..60"))

    def setup
        workday = program("workday", "06:30" => DAY, "22:30" => NIGHT)
        holiday = program("holiday", "08:00" => COMFORT)
        days = (0..6).to_h { [it, workday] }
        timetable = Schedule::Timetable.new(days:,
                                            specials: { "holiday" => holiday })
        @zone = Schedule::Zone.new(name: "salon", timetable:)
    end

    def test_the_timetable_gives_its_preset_s_bound
        decision = resolve("2026-11-02 10:00")
        assert_equal ["..60", "timetable:workday"], humidity(decision)
        assert_equal [nil, nil], humidity(resolve("2026-11-02 23:00"))
    end

    def test_a_layer_without_a_bound_keeps_the_one_below
        decision = resolve("2026-11-02 10:00", layers: manual("+22.."))
        assert_equal "+22.0..@..60", decision.setpoint.to_s
        assert_equal ["manual", "..60", "timetable:workday"],
                     [decision.source, *humidity(decision)]
    end

    def test_a_layer_s_own_bound_or_clearing_wins
        own = resolve("2026-11-02 10:00", layers: manual("+22..@..50"))
        assert_equal ["..50", "manual"], humidity(own)
        cleared = resolve("2026-11-02 10:00", layers: manual("+22..@"))
        assert_equal ["", "manual"], humidity(cleared)
        assert_predicate cleared.setpoint.humidity, :none?
    end

    # A boost, an open window and away each keep what is below.
    def test_the_other_layers_keep_the_bound_below
        boost = Schedule::Layers::Boost.new([entry(nil, mode: :for)])
        window = Schedule::Layers::OpenWindow.new([entry(nil, mode: :for)])
        away = Schedule::Layers::Away.new([],
                                          auto_since: at("2026-11-02 09:00"))
        [boost, window, away].each do |layer|
            decision = resolve("2026-11-02 10:00", layers: [base, layer])
            assert_equal ["..60", "timetable:workday"], humidity(decision),
                         decision.source
        end
    end

    def test_the_calendar_decides_afresh
        calendar = Schedule::Layers::Calendar.new(
            [ScheduleSupport.holiday(Date.new(2026, 12, 25))]
        )
        decision = resolve("2026-12-25 10:00", layers: [base, calendar])
        assert_equal ["calendar:fr:holiday", nil, nil],
                     [decision.source, *humidity(decision)]
    end

    def test_the_clamp_keeps_it
        layers = manual("+40..@..50") + [Schedule::Layers::Clamp.new]
        decision = resolve("2026-11-02 10:00", layers:)
        assert_equal "+30.0..@..50", decision.setpoint.to_s
        assert_equal ["..50", "manual"], humidity(decision)
    end

    private

    def humidity(decision)
        [decision.setpoint.humidity&.to_s, decision.humidity_source]
    end

    def manual(band)
        [base, Manual.new([entry(Schedule::Syntax.preset(band))])]
    end

    def entry(preset, mode: :forever)
        Manual::Entry.new(zone: "salon", preset:, strategy: nil,
                          starts_at: at("2026-11-02 09:00"),
                          ends_at: mode == :for ? at("2026-11-02 11:00") : nil,
                          mode:)
    end
end
