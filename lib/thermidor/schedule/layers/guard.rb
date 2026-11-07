# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # Named limits a zone must stay within whatever the layers below
            # decided: a guard's band read as bounds, not a target. Each side
            # of the band below is brought within the floor (the highest
            # heat) and the ceiling (the lowest cool) of the zone's guards,
            # an open side taking the bound; the humidity bounds likewise.
            # The caller hands over the guards in force, in a stable order
            # (the first named on a tie); which apply when is its own.
            class Guard
                # The humidity_source of bounds the guards gave where none
                # were in force.
                SOURCE = "guard"

                # A guard held by a zone: its band's sides, humidity
                # included, are bounds. One bounding nothing is refused.
                Entry = Data.define(:zone, :name, :bounds) do
                    def initialize(zone:, name:, bounds:)
                        Guard.check(name, bounds)
                        super
                    end
                end

                # Which side of a guard's band each axis's Span reads.
                TEMPERATURE = [:heat.to_proc, :cool.to_proc].freeze
                HUMIDITY = [-> { it.humidity&.low },
                            -> { it.humidity&.high }].freeze

                # A guard's bounds: a Setpoint, bounding something.
                def self.check(name, bounds)
                    unless bounds.is_a?(Setpoint)
                        raise Error, "guard #{name}: #{bounds.inspect} " \
                                     "is no band"
                    end
                    return unless bare?(bounds)
                    raise Error, "guard #{name} bounds nothing"
                end

                # No temperature side and no humidity bound.
                def self.bare?(setpoint)
                    setpoint.off? && (setpoint.humidity.nil? ||
                                      setpoint.humidity.none?)
                end

                # Guards of a zone that leave no band between them (a floor
                # and a ceiling less than the deadband apart, a humidity
                # floor at or above its ceiling) are refused, here rather
                # than when asked, as the clamp refuses such limits.
                def initialize(entries)
                    @entries = entries.dup.freeze
                    @entries.group_by(&:zone).each { spans(*it) }
                end

                def apply(zone, _now, below)
                    mine = @entries.select { it.zone == zone.name }
                    return below if mine.empty?
                    temperature, humidity = spans(zone.name, mine)
                    after = Guard.bounded(below.setpoint, temperature, humidity)
                    moved = Guard.sources(below.setpoint, after,
                                          temperature, humidity)
                    below.with(setpoint: after,
                               humidity_source: Guard.humidity_source(below,
                                                                      after),
                               guards: below.guards.merge(moved).freeze)
                end

                # SOURCE when the guards gave humidity bounds where none
                # were in force (none given, or cleared); else the one below.
                def self.humidity_source(below, after)
                    given = below.setpoint.humidity
                    none_given = given.nil? || given.none?
                    return SOURCE if none_given && after.humidity != given
                    below.humidity_source
                end

                def self.bounded(setpoint, temperature, humidity)
                    setpoint.with(**sides(setpoint, temperature),
                                  humidity: self.humidity(setpoint.humidity,
                                                          humidity))
                end

                # The band's sides within the span, an open side taking its
                # bound.
                def self.sides(setpoint, span)
                    floor, ceiling = span.bounds
                    heat = span.within(setpoint.heat) || floor
                    cool = span.within(setpoint.cool) || ceiling
                    heat, cool = Clamp.separate(heat, cool, ceiling) if
                        heat && cool
                    { heat:, cool: }
                end

                # The humidity bounds within the span, kept when it gives
                # none. Unlike a temperature side, a bound has no gap to keep
                # from the other, so one pushed onto the opposite bound is
                # dropped rather than held just short of it.
                def self.humidity(given, span)
                    return given unless span.given?
                    low, high = span.bounds
                    floor, ceiling = give_way(span.within(given&.low) || low,
                                              span.within(given&.high) || high,
                                              span)
                    Humidity.new(low: floor, high: ceiling)
                end

                # A floor pushed onto the guards' ceiling is none: it gives
                # way to the guards' floor; a ceiling, to their ceiling.
                def self.give_way(floor, ceiling, span)
                    return [floor, ceiling] unless
                        floor && ceiling && floor >= ceiling
                    low, high = span.bounds
                    floor == high ? [low, ceiling] : [floor, high]
                end

                # The guard that bound each side it moved: :heat, :cool by
                # the way they moved (a value computed from the opposite
                # bound is that bound's), :humidity_low, :humidity_high by
                # the bound they now hold.
                def self.sources(before, after, temperature, humidity)
                    moves(before, after, temperature, humidity)
                        .filter_map do |side, (from, to, span, own)|
                            [side, named(side, span, from, to, own)] unless
                                from == to
                        end.to_h
                end

                # Per side: its value before and after, its span, and which
                # of the span's bounds is its own.
                def self.moves(before, after, temperature, humidity)
                    was = before.humidity
                    now = after.humidity
                    {
                        heat: [before.heat, after.heat, temperature, :low],
                        cool: [before.cool, after.cool, temperature, :high],
                        humidity_low: [was&.low, now&.low, humidity, :low],
                        humidity_high: [was&.high, now&.high, humidity, :high]
                    }
                end

                def self.named(side, span, from, to, own)
                    return span.mover(from, to, own) if %i[heat cool]
                                                        .include?(side)
                    span.holder(to, own)
                end

                private

                # [temperature, humidity] Spans of a zone's guards.
                def spans(zone, entries)
                    found = [Span.tightest(entries, *TEMPERATURE),
                             Span.tightest(entries, *HUMIDITY)]
                    return found unless
                        found[0].narrower?(Schedule.config.deadband) ||
                        found[1].narrower?(0, touching: true)
                    raise Error, "guards #{entries.map(&:name).join(", ")} " \
                                 "of #{zone} hold no band"
                end
            end
        end
    end
end
