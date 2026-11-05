# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # Someone set a zone by hand: its preset holds until `ends_at`
            # (nil: until cleared), then the layers below take over again.
            # The end is fixed when the setting is made, whether a duration
            # or the next change below at that moment. An entry without a
            # preset holds the layer's default (see Boost); without one
            # either, the entry is refused.
            class Manual
                # The longest a manual setting may be given a duration for,
                # and what it is called when it is refused.
                LONGEST = 12 * 3600
                NOUN    = "a manual setting"
                # The modes its end may be asked by: for a while, to the
                # next change below, or until cleared. :steady, a window's,
                # is not a manual setting's.
                MODES = %i[for next forever].freeze

                # Every kind's modes: one outside them is no mode at all.
                ALL_MODES = %i[for steady next forever].freeze
                # strategy: overrides the preset's when given, through
                # Schedule.strategy (nil stays nil; a configured one, by
                # String or Symbol, its Symbol; else ParseError). mode: :for
                # (a duration), :next (the next change below) or :forever,
                # as the setting was asked for.
                Entry = Data.define(:zone, :preset, :strategy, :starts_at,
                                    :ends_at, :mode) do
                    def initialize(strategy:, **)
                        super(strategy: Schedule.strategy(strategy), **)
                    end

                    def active?(now)
                        starts_at <= now && (ends_at.nil? || now < ends_at)
                    end
                end

                # Refuses a duration (seconds) outside 0..LONGEST.
                def self.check_duration(seconds)
                    return if seconds && (0..self::LONGEST).cover?(seconds)
                    hours = self::LONGEST / 3600
                    raise Error, "#{self::NOUN} lasts 0 to #{hours} " \
                                 "hour#{"s" if hours > 1}"
                end

                # Refuses a mode no kind has with Error, another kind's
                # with ArgumentError naming this one.
                def self.check_mode(mode)
                    raise Error, "unknown mode #{mode}" unless
                        Manual::ALL_MODES.include?(mode)
                    return if self::MODES.include?(mode)
                    raise ArgumentError,
                          "#{self::NOUN} takes no #{mode.inspect} end"
                end

                # The end of a setting made at `now`, fixed then: :for (or
                # :steady, a window's limit) a checked duration; :next, the
                # next change of what `below` (a Stack of the layers under
                # this one) decides, not of a layer it hides, or LONGEST
                # ahead when that does not change;
                # :forever, nil. A mode not in the kind's MODES raises
                # ArgumentError (Error if no kind has it).
                def self.ends_at(mode, below:, zone:, now:, duration: nil)
                    check_mode(mode)
                    case mode
                    when :for, :steady
                        check_duration(duration)
                        now + duration
                    when :next
                        below.resolve(zone, now).until || (now + self::LONGEST)
                    when :forever then nil
                    else raise Error, "unknown mode #{mode}"
                    end
                end

                def initialize(entries, source: "manual", default: nil)
                    @entries = entries.dup.freeze
                    @source  = source
                    @default = default
                    refuse_bare
                end

                # The last entry of the zone running now holds; one listed
                # after it, or any with none running, still to start, is a
                # change ahead.
                def apply(zone, now, below)
                    mine  = @entries.select { it.zone == zone.name }
                    index = mine.rindex { it.active?(now) }
                    decision = index ? held(mine[index], zone) : below
                    later = mine.drop(index ? index + 1 : 0)
                                .map(&:starts_at).select { it > now }.min
                    decision.sooner(later)
                end

                private

                def held(entry, zone)
                    Decision.from_preset(entry.preset || default_for(entry),
                                         zone,
                                         override: entry.strategy,
                                         source: @source, until: entry.ends_at)
                end

                # An entry with no band to hold: no preset, and no default.
                def refuse_bare
                    bare = @entries.find { it.preset.nil? && !default_for(it) }
                    return unless bare
                    raise Error, "manual entry for #{bare.zone} has no " \
                                 "preset, and the layer no default"
                end

                def default_for(_entry) = @default
            end
        end
    end
end
