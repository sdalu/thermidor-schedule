# frozen_string_literal: true

require "test_helper"
require "support"

# Rules as a calendar file writes them.
class RecurrenceImportTest < Minitest::Test
    include ScheduleSupport

    def test_a_leading_rrule_is_dropped
        %w[RRULE:FREQ=WEEKLY;BYDAY=WE rrule:freq=weekly;byday=we].each do |text|
            assert_equal "FREQ=WEEKLY;BYDAY=WE",
                         Schedule::Recurrence.parse(text).to_s, text
        end
        assert_raises(Schedule::ParseError) do
            Schedule::Recurrence.parse("FREQ=DAILY;RRULE:COUNT=2")
        end
    end

    # 23:00 UTC on 30 June is 1 July in Paris, 30 June in New York; a time
    # without Z is local already.
    def test_an_until_in_utc_ends_on_its_local_date
        {
            "Europe/Paris" => [Date.new(2027, 7, 1), Date.new(2027, 6, 30)],
            "America/New_York" => [Date.new(2027, 6, 30), Date.new(2027, 6, 30)]
        }.each do |zone, expected|
            in_zone(zone) do
                stamps = %w[20270630T230000Z 20270630T230000]
                untils = stamps.map { until_of(it) }
                assert_equal expected, untils, zone
            end
        end
    end

    def test_the_last_date_is_the_local_one
        in_zone("Europe/Paris") do
            rule = Schedule::Recurrence.parse(
                "FREQ=DAILY;UNTIL=20270630T230000Z"
            )
            dates = rule.occurrences(Date.new(2027, 6, 29),
                                     Date.new(2027, 7, 5))
            assert_equal Date.new(2027, 7, 1), dates.last
        end
    end

    private

    def until_of(stamp)
        Schedule::Recurrence.parse("FREQ=DAILY;UNTIL=#{stamp}").until
    end
end
