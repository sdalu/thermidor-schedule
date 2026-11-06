# frozen_string_literal: true

require "test_helper"
require "support"

# A calendar entry's priority is a whole number, 1 or more (1 the
# highest); anything else is refused when the entry is built.
class CalendarPriorityTest < Minitest::Test
    include ScheduleSupport

    Entry = Schedule::Layers::Calendar::Entry

    def test_a_priority_of_one_or_more_is_taken
        assert_equal 1, entry(1).priority
        assert_equal 16, entry(16).priority
    end

    def test_any_other_priority_is_refused
        [0, -1, 1.5, "8", nil].each do |priority|
            assert_raises(ArgumentError, priority.inspect) { entry(priority) }
        end
    end

    private

    def entry(priority)
        ScheduleSupport.holiday(Date.new(2026, 12, 24),
                                calendar: "c", priority:)
    end
end
