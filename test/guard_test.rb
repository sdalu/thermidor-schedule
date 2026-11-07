# frozen_string_literal: true

require "test_helper"
require "support"

# Guards: limits a zone stays within whatever was decided below, several
# intersecting, each side naming the guard that bound it. The house's:
# frost (+7..), damp (@..65), floor-bamboo (+15..+25@40..65).
class GuardTest < Minitest::Test
    include ScheduleSupport

    Guard  = Schedule::Layers::Guard
    Manual = Schedule::Layers::Manual

    def setup
        @zone = workday_zone
    end

    def test_a_band_within_the_guards_passes_untouched
        decision = guarded("+20..+24@45..60", bedroom)
        assert_equal "+20.0..+24.0@45..60", decision.setpoint.to_s
        assert_empty decision.guards
    end

    # An off side under a floor, or over a ceiling, takes the bound.
    def test_off_takes_the_guards_bounds
        decision = guarded("off", bedroom)
        assert_equal "+15.0..+25.0@40..65", decision.setpoint.to_s
        assert_equal({ heat: "floor-bamboo", cool: "floor-bamboo",
                       humidity_low: "floor-bamboo", humidity_high: "damp" },
                     decision.guards)
        assert_equal "+7.0..", guarded("off", [guard("frost", "+7..")])
            .setpoint.to_s
    end

    # Heat above the ceiling comes down to it; cool then gives way up to
    # the ceiling, and heat steps down by the deadband.
    def test_a_side_beyond_the_ceiling_is_held_under_it
        decision = guarded("+28..", bedroom)
        assert_equal "+24.0..+25.0", decision.setpoint.to_s.split("@").first
        assert_equal %w[floor-bamboo floor-bamboo],
                     decision.guards.values_at(:heat, :cool)
    end

    def test_the_tightest_bound_wins_the_first_named_on_a_tie
        guards = [guard("frost", "+7.."), guard("bamboo", "+15..+25"),
                  guard("gerflor", "+15..+28")]
        decision = guarded("+10..+30", guards)
        assert_equal "+15.0..+25.0", decision.setpoint.to_s
        assert_equal({ heat: "bamboo", cool: "bamboo" }, decision.guards)
    end

    # Named for the guard that moved a side, by the way it moved, even
    # where it lands on the other guard's bound.
    def test_a_side_is_named_for_the_guard_that_pushed_it
        guards = [guard("warm", "+24.."), guard("cap", "..+25")]
        assert_equal({ heat: "cap", cool: "cap" },
                     guarded("+28..", guards).guards)
        assert_equal({ heat: "warm", cool: "warm" },
                     guarded("..+10", guards).guards)
    end

    # Two guard layers: the upper adds to what the lower named.
    def test_stacked_guards_add_to_the_sides_named
        layers = manual("off") + [Guard.new([guard("frost", "+7..")]),
                                  Guard.new([guard("damp", "@..65")])]
        decision = resolve("2026-11-02 10:00", layers:)
        assert_equal ["+7.0..@..65", { heat: "frost", humidity_high: "damp" }],
                     [decision.setpoint.to_s, decision.guards]
    end

    # Bounds where none were in force are the guards'; a bound tightened
    # stays its layer's.
    def test_the_humidity_source_is_the_guards_where_they_gave_it
        sources = ["+20..+24", "+20..+24@", "+20..+24@45.."]
                  .map { |band| guarded(band, bedroom).humidity_source }
        assert_equal %w[guard guard manual], sources
    end

    def test_humidity_kept_or_cleared_below_is_bounded_still
        damp = [guard("damp", "@..65")]
        assert_equal "+20.0..+24.0@..65",
                     guarded("+20..+24", damp).setpoint.to_s
        assert_equal "+20.0..+24.0@..65",
                     guarded("+20..+24@", damp).setpoint.to_s
        lowered = guarded("+20..+24@..70", damp)
        assert_equal ["..65", { humidity_high: "damp" }],
                     [lowered.setpoint.humidity.to_s, lowered.guards]
    end

    # A floor of 70 under a ceiling of 65 is none: it gives way to the
    # guards' floor, named for the guard whose bound it now holds, or is
    # dropped, named for the ceiling that dropped it.
    def test_a_humidity_bound_beyond_the_opposite_one_gives_way
        decision = guarded("+20..+24@70..", [guard("damp", "@..65")])
        assert_equal "..65", decision.setpoint.humidity.to_s
        assert_equal({ humidity_low: "damp", humidity_high: "damp" },
                     decision.guards)
        bamboo = guarded("+20..+24@70..", bedroom)
        assert_equal ["40..65", { humidity_low: "floor-bamboo",
                                  humidity_high: "damp" }],
                     [bamboo.setpoint.humidity.to_s, bamboo.guards]
    end

    def test_another_zone_s_guards_change_nothing
        layer = Guard.new([guard("bamboo", "+15..+25", zone: "office")])
        below = resolve("2026-11-02 10:00", layers: [base])
        assert_same below, layer.apply(@zone, at("2026-11-02 10:00"), below)
    end

    # Under the clamp: it keeps what the guards named, and their source.
    def test_the_clamp_above_keeps_the_guards
        layers = manual("off") + [Guard.new([guard("hot", "+35..")]),
                                  Schedule::Layers::Clamp.new]
        decision = resolve("2026-11-02 10:00", layers:)
        assert_equal ["+30.0..", { heat: "hot" }, "manual"],
                     [decision.setpoint.to_s, decision.guards,
                      decision.source]
    end

    private

    def bedroom
        [guard("frost", "+7.."), guard("damp", "@..65"),
         guard("floor-bamboo", "+15..+25@40..65")]
    end

    def guard(name, text, zone: "salon")
        Guard::Entry.new(zone:, name:, bounds: Schedule::Syntax.guard(text))
    end

    def guarded(band, guards)
        resolve("2026-11-02 10:00",
                layers: manual(band) + [Guard.new(guards)])
    end

    def manual(band)
        entry = Manual::Entry.new(zone: "salon", strategy: nil,
                                  preset: Schedule::Syntax.preset(band),
                                  starts_at: at("2026-11-02 09:00"),
                                  ends_at: nil, mode: :forever)
        [base, Manual.new([entry])]
    end
end
