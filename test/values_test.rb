# frozen_string_literal: true

require "test_helper"
require "support"

# What the gem keeps of what it is given is its own, and what it hands
# out stays as built.
class ValuesTest < Minitest::Test
    include ScheduleSupport

    def setup
        @zone = workday_zone
    end

    def test_a_stack_leaves_the_callers_array_alone
        layers = [base]
        Schedule::Stack.new(layers)
        refute_predicate layers, :frozen?
    end

    # An entry the caller adds after building the layer is not its own:
    # it would have been refused, having no band to hold.
    def test_a_layer_keeps_its_entries_as_given
        entries = []
        layer = Schedule::Layers::Manual.new(entries)
        entries << Schedule::Layers::Manual::Entry.new(
            zone: "salon", preset: nil, strategy: nil,
            starts_at: at("2026-11-02 09:00"), ends_at: nil, mode: :forever
        )
        below = resolve("2026-11-02 10:00")
        assert_equal below, layer.apply(@zone, at("2026-11-02 10:00"),
                                        below)
    end

    def test_a_parsed_rule_is_frozen_through
        rule = Schedule::Recurrence.parse(
            "FREQ=MONTHLY;BYDAY=-1FR,MO;BYMONTHDAY=1;BYMONTH=3"
        )
        [rule.by_day, *rule.by_day, rule.by_month_day, rule.by_month]
            .each { assert_predicate it, :frozen? }
    end
end
