# frozen_string_literal: true

require "test_helper"

# A calendar entry repeated by its rule.
class CalendarOccurrencesTest < Minitest::Test
    Schedule = Thermidor::Schedule

    CHRISTMAS = Schedule::Layers::Calendar::Entry.new(
        id: 1, calendar: "fr", priority: 8, zone: nil, kind: "holiday",
        first: Date.new(2026, 12, 24), last: Date.new(2026, 12, 25),
        description: nil
    )

    def test_a_recurring_entry_repeats_as_a_whole_but_its_skipped_dates
        rule  = Schedule::Recurrence.parse("FREQ=YEARLY;COUNT=3")
        found = CHRISTMAS.occurrences(rule, Date.new(2030, 1, 1),
                                      skipped: [Date.new(2027, 12, 24)])
        spans = found.map { [it.first.year, it.first.day, it.last.day] }
        assert_equal [[2026, 24, 25], [2028, 24, 25]], spans
    end

    def test_an_entry_without_a_rule_stands_alone
        assert_equal [CHRISTMAS], CHRISTMAS.occurrences(nil, Date.new(2030))
    end
end
