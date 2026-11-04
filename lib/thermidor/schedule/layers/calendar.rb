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
            # carry on from the evening before it).
            class Calendar
                # `first` and `last` are Dates, both included; `kind` is
                # already resolved from the entry's calendar when the entry
                # names none.
                Entry = Data.define(:id, :calendar, :priority, :zone, :kind,
                                    :first, :last, :description) do
                    def covers?(date, zone_name)
                        (first..last).cover?(date) &&
                            (zone.nil? || zone == zone_name)
                    end

                    # Smallest first: the entry that wins.
                    def rank = [priority, zone ? 0 : 1, -id]
                end

                def initialize(entries)
                    @entries = entries
                end

                def apply(zone, now, below)
                    lookup = ->(date) { program_on(zone, date) }
                    entry  = zone.timetable.at(now, &lookup) or return below
                    Decision.from_preset(
                        entry.transition.preset, zone,
                        override: entry.transition.strategy,
                        source: source(zone, entry),
                        until: zone.timetable.next_change(now, &lookup)
                    )
                end

                private

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
