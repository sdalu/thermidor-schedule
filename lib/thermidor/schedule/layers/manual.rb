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
                # The longest a manual setting may be given a duration for.
                LONGEST = 12 * 3600
                # strategy: overrides the preset's when given. mode: :for (a
                # duration), :next (the next change below) or :forever, as
                # the setting was asked for.
                Entry = Data.define(:zone, :preset, :strategy, :starts_at,
                                    :ends_at, :mode) do
                    def active?(now)
                        starts_at <= now && (ends_at.nil? || now < ends_at)
                    end
                end

                def initialize(entries, source: "manual", default: nil)
                    @entries = entries
                    @source  = source
                    @default = default
                    refuse_bare
                end

                def apply(zone, now, below)
                    entry = @entries.reverse.find do |candidate|
                        candidate.zone == zone.name && candidate.active?(now)
                    end
                    return below unless entry
                    Decision.from_preset(entry.preset || default_for(entry),
                                         zone,
                                         override: entry.strategy,
                                         source: @source, until: entry.ends_at)
                end

                private

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
