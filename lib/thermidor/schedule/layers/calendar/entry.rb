# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            class Calendar
                # `first` and `last` are Dates, both included; `kind` is
                # already resolved from the entry's calendar when the entry
                # names none.
                Entry = Data.define(:id, :calendar, :priority, :zone, :kind,
                                    :first, :last, :description) do
                    # A priority, and a kind as Syntax.day_kind gives it
                    # ("sun".."sat" or a special day's name), or
                    # ArgumentError.
                    def initialize(priority:, kind:, **)
                        Calendar.check_entry(priority, kind)
                        super
                    end

                    def covers?(date, zone_name)
                        (first..last).cover?(date) &&
                            (zone.nil? || zone == zone_name)
                    end

                    # Smallest first: the entry that wins.
                    def rank = [priority, zone ? 0 : 1, -id]

                    # The entry repeated by `rule` (a Recurrence; nil, the
                    # entry alone) up to `upto`, its range as a whole, but
                    # the occurrences starting on a `skipped` date; with
                    # `from`, those that reach it (start no earlier than
                    # its length before it).
                    def occurrences(rule, upto, skipped: [], from: nil)
                        return reaching(upto, from) unless rule
                        span = last - first
                        starts = rule.occurrences(first, upto,
                                                  from: from && (from - span))
                        (starts - skipped)
                            .map { with(first: it, last: it + span) }
                    end

                    # The entry alone, if it starts by `upto` and reaches
                    # `from` (nil: any).
                    def reaching(upto, from)
                        return [] if first > upto || (from && last < from)
                        [self]
                    end
                end

                def self.check_entry(priority, kind)
                    unless priority.is_a?(Integer) && priority.positive?
                        raise ArgumentError, "a calendar entry's priority " \
                                             "is a whole number, 1 or more"
                    end
                    return if kind?(kind)
                    raise ArgumentError, "#{kind.inspect} is no kind of day"
                end

                def self.kind?(kind)
                    kind.is_a?(String) && Syntax.day_kind(kind) == kind
                rescue ParseError
                    false
                end
            end
        end
    end
end
