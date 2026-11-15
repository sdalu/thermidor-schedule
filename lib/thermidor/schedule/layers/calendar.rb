# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # Dates that run another kind of day: a special day ("holiday")
            # or a weekday ("sun"), for the whole house (entry zone nil) or
            # one zone. Each zone runs its own program for that kind; an
            # entry for a kind the zone has no program for does not apply
            # to it, as one for another zone would not. The entries that
            # apply stack: the calendar with the highest priority (1) on
            # top, then a zone's own entry over a house-wide one, then the
            # latest added, and the zone's weekday program under them. The
            # top one decides, unless its program lets another through (a
            # transition holding pass, usual or fallback: see
            # Schedule::Timetable::Resolver); with none, the zone keeps its
            # usual day. A zone binding the kind to
            # Schedule::Timetable::USUAL takes the entry and runs its usual
            # weekday, the entries below it left out.
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
                # `fallback`: what a program's keyword lets through to.
                def initialize(entries, fallback: Preset.frost)
                    raise Error, "a calendar layer needs a fallback" unless
                        fallback
                    @entries  = entries.dup.freeze
                    @fallback = fallback
                end

                # A calendar day still to come is a change ahead even when
                # nothing runs through the calendar yet.
                def apply(zone, now, below)
                    resolver = resolver(zone)
                    found  = resolver.at(now)
                    change = resolver.next_change(now)
                    return below.sooner(change) if found.chain.empty? ||
                                                   unchanged?(zone, now, found,
                                                              change)
                    decided(zone, found, change)
                end

                # The Resolution in force at `time` in `zone`, as the layer
                # sees it (Calendar::Seen); `source` names who said it.
                def at(zone, time) = seen(zone).at(time)

                # The day `date` runs in `zone`, as the Stretches that make
                # it, from its midnight to the next; a stretch ends where
                # its preset, strategy or source does.
                def day(zone, date)
                    Stretch.day(seen(zone), date) { source(it) }
                end

                # Who said `found`, as a decision's source.
                def source(found)
                    return "fallback" if found.fallback?
                    entry = found.level.entry
                    return "calendar:#{entry.calendar}:#{entry.kind}" if entry
                    "timetable:#{found.program.label}"
                end

                private

                def seen(zone)
                    Seen.new(resolver(zone),
                             zone.timetable.resolver(fallback: @fallback))
                end

                def resolver(zone)
                    zone.timetable.resolver(fallback: @fallback) do |date|
                        levels_on(zone, date)
                    end
                end

                def decided(zone, found, change)
                    decision = Decision.from_preset(
                        found.preset, zone,
                        override: found.strategy,
                        source: source(found), until: change
                    )
                    decision.with(on_time: found.on_time)
                            .sooner(out_of_sight(found.chain.map(&:date).min))
                end

                # What is in force owes nothing to a calendar entry, and it
                # and the next change are what the weekday timetable alone
                # gives.
                def unchanged?(zone, now, found, change)
                    plain = zone.timetable.resolver(fallback: @fallback)
                    found.chain.none? { it.level.entry } &&
                        plain.at(now) == found &&
                        plain.next_change(now) == change
                end

                # When what ran on `date` is no longer seen: the timetable
                # looks back REACH dates, so midnight the date after that.
                # Only a zone with no weekday program carries a day so long.
                def out_of_sight(date)
                    gone = date + Schedule::Timetable::REACH + 1
                    LocalTime.at(gone, 0)
                end

                # The stack of `date` in `zone`: the levels of the entries
                # that apply, best ranked first, then the weekday's. An entry
                # whose day the zone binds to USUAL runs the weekday there,
                # the entries ranked below it left out.
                def levels_on(zone, date)
                    level = Schedule::Timetable::Level
                    levels = []
                    applying_on(zone, date).each do |entry, program|
                        if program.equal?(Schedule::Timetable::USUAL)
                            program = zone.timetable.days[date.wday]
                            return levels << level.weekday(program, entry:)
                        end
                        levels << level.new(program:, entry:)
                    end
                    levels << zone.timetable.weekday(date)
                end

                # [entry, program] of every entry `date` follows in `zone`,
                # those the zone has a program for, best ranked first.
                def applying_on(zone, date)
                    @entries.select { it.covers?(date, zone.name) }
                            .filter_map { applying(zone, it) }
                            .sort_by { |entry, _| entry.rank }
                end

                def applying(zone, entry)
                    program = zone.timetable.program_for(entry.kind)
                    [entry, program] if program
                end
            end
        end
    end
end
