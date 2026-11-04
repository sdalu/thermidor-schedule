# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # Dates that run another kind of day: a special day ("holiday")
            # or a weekday ("sun"), for the whole house (entry zone nil) or
            # one zone. Each zone runs its own program for that kind; a zone
            # without one keeps its usual day. When entries overlap, the
            # calendar with the highest priority (1) wins, then a zone's own
            # entry over a house-wide one, then the latest added.
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
                    found = entry_on(zone, entry.date)
                    return "calendar:#{found.calendar}:#{found.kind}" if found
                    "timetable:#{entry.program.label}"
                end

                def program_on(zone, date)
                    found = entry_on(zone, date)
                    return zone.timetable.days[date.wday] unless found
                    zone.timetable.program_for(found.kind)
                end

                # The entry `date` follows in `zone`, if the zone has a
                # program for its kind.
                def entry_on(zone, date)
                    entry = @entries.select { it.covers?(date, zone.name) }
                                    .min_by(&:rank)
                    entry if entry && zone.timetable.program_for(entry.kind)
                end
            end
        end
    end
end
