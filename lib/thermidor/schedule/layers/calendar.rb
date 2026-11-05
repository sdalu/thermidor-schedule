# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # Dates that run another kind of day: a special day ("holiday")
            # or a weekday ("sun"), for the whole house (entry zone nil) or
            # one zone. Each zone runs its own program for that kind; an
            # entry for a kind the zone has no program for does not apply
            # to it, as one for another zone would not. Of the entries that
            # apply, the calendar with the highest priority (1) wins, then
            # a zone's own entry over a house-wide one, then the latest
            # added; with none, the zone keeps its usual day. A zone binding
            # the kind to Schedule::Timetable::USUAL takes the entry and
            # runs its usual weekday.
            #
            # The timetable below does not know these dates, so this layer
            # decides afresh from the dates' programs, even when what is in
            # force comes from an ordinary day (the early hours of a holiday
            # carry on from the evening before it). When the calendar
            # changes nothing, now or next (what is in force comes from a
            # date with no entry, and both it and the next change are the
            # weekday timetable's), it passes the decision below through,
            # a layer of the caller's own between them kept. On the eve of
            # a calendar day it decides, the timetable's next change below
            # not being the one that comes.
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
                        return [self] unless rule
                        span = last - first
                        starts = rule.occurrences(first, upto,
                                                  from: from && (from - span))
                        (starts - skipped)
                            .map { with(first: it, last: it + span) }
                    end
                end

                def self.check_entry(priority, kind)
                    raise ArgumentError, "a calendar entry needs a priority" if
                        priority.nil?
                    return if kind?(kind)
                    raise ArgumentError, "#{kind.inspect} is no kind of day"
                end

                def self.kind?(kind)
                    kind.is_a?(String) && Syntax.day_kind(kind) == kind
                rescue ParseError
                    false
                end

                def initialize(entries)
                    @entries = entries.dup.freeze
                end

                # A calendar day still to come is a change ahead even when
                # nothing runs through the calendar yet.
                def apply(zone, now, below)
                    lookup = ->(date) { program_on(zone, date) }
                    change = zone.timetable.next_change(now, &lookup)
                    entry  = zone.timetable.at(now, &lookup)
                    return below.sooner(change) if
                        entry.nil? || unchanged?(zone, now, entry, change)
                    decided(zone, entry, change)
                end

                private

                def decided(zone, entry, change)
                    Decision.from_preset(
                        entry.transition.preset, zone,
                        override: entry.transition.strategy,
                        source: source(zone, entry), until: change
                    ).sooner(out_of_sight(entry.date))
                end

                # What is in force comes from a date with no entry, and it
                # and the next change are what the weekday timetable alone
                # gives.
                def unchanged?(zone, now, entry, change)
                    entry_on(zone, entry.date).nil? &&
                        zone.timetable.at(now) == entry &&
                        zone.timetable.next_change(now) == change
                end

                # When what ran on `date` is no longer seen: the timetable
                # looks back REACH dates, so midnight the date after that.
                # Only a zone with no weekday program carries a day so long.
                def out_of_sight(date)
                    gone = date + Schedule::Timetable::REACH + 1
                    Time.new(gone.year, gone.month, gone.day)
                end

                def source(zone, entry)
                    found, = entry_on(zone, entry.date)
                    return "calendar:#{found.calendar}:#{found.kind}" if found
                    "timetable:#{entry.program.label}"
                end

                def program_on(zone, date)
                    _, program = entry_on(zone, date)
                    usual = program.nil? || program.equal?(Schedule::Timetable::USUAL)
                    usual ? zone.timetable.days[date.wday] : program
                end

                # [entry, program]: the entry `date` follows in `zone`, the
                # best ranked of those the zone has a program for, and that
                # program; nil if none applies.
                def entry_on(zone, date)
                    @entries.select { it.covers?(date, zone.name) }
                            .filter_map { applying(zone, it) }
                            .min_by { |entry, _| entry.rank }
                end

                def applying(zone, entry)
                    program = zone.timetable.program_for(entry.kind)
                    [entry, program] if program
                end
            end
        end
    end
end
