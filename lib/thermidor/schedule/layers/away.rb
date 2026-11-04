# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # Nobody is home, said zone by zone (`away on` without a zone
            # gives every zone an entry); the latest entry of a zone wins,
            # and any beats an automatic away period (`auto_since`, the
            # time the house became empty enough for one) started from
            # presence. When it ends, the layers below take over again.
            class Away
                # `preset` nil means the default away preset; `ends_at`
                # nil means until someone says otherwise.
                Entry = Data.define(:zone, :preset, :starts_at, :ends_at) do
                    def active?(now)
                        starts_at <= now && (ends_at.nil? || now < ends_at)
                    end
                end

                def initialize(entries, default: Preset::AWAY,
                               auto_since: nil)
                    raise Error, "an away layer needs a default" unless default
                    @entries    = entries
                    @default    = default
                    @auto_since = auto_since
                end

                def apply(zone, now, below)
                    entry = entry_for(zone, now)
                    return automatic(zone, now, below) unless entry
                    Decision.from_preset(entry.preset || @default, zone,
                                         source: "away",
                                         until: entry.ends_at)
                end

                private

                # Until presence changes, which nothing here can tell; one
                # still to start is a change ahead.
                def automatic(zone, now, below)
                    return below unless @auto_since
                    if @auto_since > now
                        ahead = [below.until, @auto_since].compact.min
                        return below.with(until: ahead)
                    end
                    Decision.from_preset(@default, zone, source: "away:auto",
                                                         until: nil)
                end

                def entry_for(zone, now)
                    @entries.select { it.zone == zone.name && it.active?(now) }
                            .max_by(&:starts_at)
                end
            end
        end
    end
end
