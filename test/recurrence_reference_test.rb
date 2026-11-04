# frozen_string_literal: true

require "rrule"
require "test_helper"

# Recurrence against the rrule gem, an independent RFC 5545
# implementation, over rules generated from a fixed seed: the expansion
# is where ordinals, negative month days and intervals meet, which
# examples written by hand cover only in part.
class RecurrenceReferenceTest < Minitest::Test
    Schedule = Thermidor::Schedule

    SEED  = 20_261_104
    RULES = 500
    UPTO  = Date.new(2030, 12, 31)
    DAYS  = %w[MO TU WE TH FR SA SU].freeze

    def test_agrees_with_the_reference
        random = Random.new(SEED)
        compared = Array.new(RULES) { compare(rule_text(random), random) }
        assert_operator compared.count(true), :>, RULES / 2,
                        "too few rules compared"
    end

    private

    # true when compared, nil when the reference yields no date to start
    # from. rrule leaves out a start date the rule does not match, which
    # RFC 5545 counts: both start from the first date the rule yields.
    def compare(text, random)
        start = Date.new(2026, 1, 1) + random.rand(365)
        first = reference(text, start).first or return
        ours  = Schedule::Recurrence.parse(text).occurrences(first, UPTO)
        assert_equal reference(text, first), ours, "#{text} from #{first}"
        true
    end

    # UNTIL is the last date, included (RFC 5545 3.3.10); rrule leaves
    # out a date-only UNTIL's own day, so it is given that day's end.
    # max_year: rrule looks for a rule that never matches up to 9999,
    # seconds a rule.
    def reference(text, start)
        time = Time.utc(start.year, start.month, start.day)
        text = text.sub(/UNTIL=(\d{8})\b/) { "UNTIL=#{it[6, 8]}T235959Z" }
        RRule::Rule.new(text, dtstart: time, tzid: "UTC", max_year: UPTO.year)
                   .between(time, Time.utc(UPTO.year, 12, 31, 23, 59))
                   .map(&:to_date)
    end

    def rule_text(random)
        freq  = %w[DAILY WEEKLY MONTHLY YEARLY].sample(random:)
        parts = ["FREQ=#{freq}"]
        parts << "INTERVAL=#{random.rand(2..3)}" if random.rand < 0.3
        parts.concat(by_parts(freq, random))
        parts << ending(random)
        parts.compact.join(";")
    end

    # BYDAY ordinals only where the parser takes them: monthly, or
    # yearly with BYMONTH, which a yearly rule here always has.
    def by_parts(freq, random)
        months = (months(random) if freq == "YEARLY" || random.rand < 0.2)
        ordinals = %w[MONTHLY YEARLY].include?(freq)
        [months && "BYMONTH=#{months}", by_day(ordinals, random),
         (month_days(random) if freq != "WEEKLY" && random.rand < 0.4)]
    end

    def months(random)
        (1..12).to_a.sample(random.rand(1..3), random:).sort.join(",")
    end

    def by_day(ordinals, random)
        return if random.rand < 0.4
        days = DAYS.sample(random.rand(1..3), random:)
        days = days.map { "#{[1, 2, -1].sample(random:)}#{it}" } if
            ordinals && random.rand < 0.5
        "BYDAY=#{days.join(",")}"
    end

    def month_days(random)
        days = [1, 15, 28, 29, 30, 31, -1, -2]
        "BYMONTHDAY=#{days.sample(random.rand(1..2), random:).join(",")}"
    end

    def ending(random)
        case random.rand(3)
        when 0 then "COUNT=#{random.rand(1..20)}"
        when 1 then "UNTIL=#{(Date.new(2027, 1, 1) + random.rand(900))
                             .strftime("%Y%m%d")}"
        end
    end
end
