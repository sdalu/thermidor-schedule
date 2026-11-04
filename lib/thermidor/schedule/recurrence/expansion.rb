# frozen_string_literal: true

module Thermidor
    module Schedule
        class Recurrence
            # The dates a rule yields, period after period (a day, a week
            # starting on Monday, a month or a year, every INTERVAL of
            # them), from the period of `first` until periods start after
            # `last`.
            class Expansion
                def initialize(rule, first, last)
                    @rule  = rule
                    @first = first
                    @last  = last
                end

                # Yields each date of the rule, in order and once (-1 and 30
                # are one day in November), up to `last`. A period starts
                # after every date of the one before it.
                def each(&)
                    step = 0
                    while (start = period(step * @rule.interval)) <= @last
                        dates(start).uniq.sort.take_while { it <= @last }
                                    .each(&)
                        step += 1
                    end
                end

                private

                def period(offset)
                    case @rule.freq
                    when :daily   then @first + offset
                    when :weekly  then monday(@first) + (7 * offset)
                    when :monthly then month_start(@first) >> offset
                    when :yearly  then Date.new(@first.year + offset, 1, 1)
                    end
                end

                def dates(start)
                    case @rule.freq
                    when :daily   then [start].select { matches?(it) }
                    when :weekly  then week(start)
                    when :monthly then month(start)
                    when :yearly  then months(start.year).flat_map { month(it) }
                    end
                end

                def week(monday)
                    days = weekdays.empty? ? [@first.wday] : weekdays
                    (0..6).map { monday + it }
                          .select { days.include?(it.wday) && in_month?(it) }
                end

                def months(year)
                    numbers = @rule.by_month
                    numbers = [@first.month] if numbers.empty?
                    numbers.map { Date.new(year, it, 1) }
                end

                # The dates of a month the rule picks.
                def month(start)
                    return [] unless in_month?(start)
                    picked(start)
                end

                # BYMONTHDAY narrowed by BYDAY (ordinals included, the
                # month's nth such day), else BYDAY, else the first date's
                # day.
                def picked(start)
                    if @rule.by_month_day.any?
                        days = month_days(start)
                        return @rule.by_day.any? ? days & by_day(start) : days
                    end
                    return by_day(start) if @rule.by_day.any?
                    month_days(start, [@first.day])
                end

                def month_days(start, days = @rule.by_month_day)
                    length = (start >> 1) - start
                    days.map { it.negative? ? length + it + 1 : it }
                        .grep(1..length)
                        .map { start + it - 1 }
                end

                # Every such weekday of the month, or the nth (from the
                # end when negative).
                def by_day(start)
                    all = (start...(start >> 1)).to_a
                    @rule.by_day.flat_map do |ordinal, wday|
                        same = all.select { it.wday == wday }
                        next same unless ordinal
                        index = ordinal.positive? ? ordinal - 1 : ordinal
                        [same[index]].compact
                    end
                end

                # Plain BYDAY weekdays; ordinal ones are handled by by_day.
                def weekdays
                    @rule.by_day.reject { |ordinal, _| ordinal }.map(&:last)
                end

                def matches?(date)
                    in_month?(date) && weekday?(date) &&
                        (@rule.by_month_day.empty? ||
                         month_days(month_start(date)).include?(date))
                end

                def weekday?(date)
                    weekdays.empty? || weekdays.include?(date.wday)
                end

                def in_month?(date)
                    @rule.by_month.empty? || @rule.by_month.include?(date.month)
                end

                def monday(date) = date - ((date.wday - 1) % 7)
                def month_start(date) = Date.new(date.year, date.month, 1)
            end
        end
    end
end
