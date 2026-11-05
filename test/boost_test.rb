# frozen_string_literal: true

require "test_helper"
require "support"

# The boost layer's directions: an entry without a preset holds the
# default of its mode. 2026-11-02 is a Monday.
class BoostTest < Minitest::Test
    include ScheduleSupport

    Boost = Schedule::Layers::Boost

    def setup
        @zone = workday_zone
    end

    def test_each_direction_has_its_built_in_preset
        labels = %i[both heat cool].map { label(Boost.new([entry(it)])) }
        assert_equal %w[boost boost-heat boost-cool], labels
    end

    def test_the_built_in_presets_are_the_system_ones
        assert_equal [Schedule::Preset::BOOST, Schedule::Preset::BOOST_HEAT,
                      Schedule::Preset::BOOST_COOL],
                     Boost::DEFAULTS.values_at(:both, :heat, :cool)
    end

    def test_defaults_given_replace_only_their_direction
        layer = ->(mode) { Boost.new([entry(mode)], defaults: { heat: ECO }) }
        labels = %i[both heat cool].map { label(layer.call(it)) }
        assert_equal %w[boost eco boost-cool], labels
    end

    def test_another_mode_falls_back_on_both
        assert_equal "boost", label(Boost.new([entry(:for)]))
        assert_equal "eco", label(Boost.new([entry(:next)],
                                            defaults: { both: ECO }))
    end

    def test_a_preset_given_beats_the_direction
        layer = Boost.new([entry(:heat).with(preset: NIGHT)])
        assert_equal %w[night boost],
                     resolve("2026-11-02 10:00", layers: [base, layer])
                         .to_h.values_at(:label, :source)
    end

    private

    def label(layer)
        resolve("2026-11-02 10:00", layers: [base, layer]).label
    end

    def entry(mode)
        Schedule::Layers::Manual::Entry.new(
            zone: "salon", preset: nil, strategy: nil,
            starts_at: at("2026-11-02 09:30"),
            ends_at: at("2026-11-02 10:30"), mode:
        )
    end
end
