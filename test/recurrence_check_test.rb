# frozen_string_literal: true

require "test_helper"

# A Recurrence built directly, not parsed, checks itself.
class RecurrenceCheckTest < Minitest::Test
    # A rule built directly checks itself as parsing does: an interval of
    # 0 would never move on.
    def test_a_rule_built_directly_checks_itself
        [{ interval: 0 }, { interval: -1 }, { interval: 1.5 },
         { freq: :hourly }].each do |bad|
            assert_raises(Thermidor::Schedule::Error, bad.inspect) do
                Thermidor::Schedule::Recurrence.new(
                    freq: :daily, interval: 1, by_day: [], by_month_day: [],
                    by_month: [], until: nil, count: nil, **bad
                )
            end
        end
    end
end
