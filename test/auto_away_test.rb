# frozen_string_literal: true

require "test_helper"

class AutoAwayTest < Minitest::Test
    Schedule = Thermidor::Schedule
    T = Time.new(2026, 11, 2, 9, 0)

    # A person's presence as AutoAway reads it.
    Status = Data.define(:since, :close) do
        def close? = close
    end

    def test_starts_the_leave_delay_after_the_last_to_go
        assert_equal T + 600 + 1200, rule.start([away(T), away(T + 600)])
    end

    def test_not_while_someone_is_or_may_be_home
        assert_nil rule.start([away(T), Status.new(since: T, close: true)])
        assert_nil rule.start([])
    end

    def test_the_leave_delay_is_given
        assert_equal T + 60, Schedule::AutoAway.new(leave: 60).start([away(T)])
    end

    private

    def rule = Schedule::AutoAway.new

    def away(since) = Status.new(since:, close: false)
end
