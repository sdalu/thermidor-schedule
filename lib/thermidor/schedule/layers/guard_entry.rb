# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # A guard as handed to the layer (Guard), and its checks.
            class Guard
                # A guard held by a zone: its band's sides, humidity
                # included, are bounds. One bounding nothing is refused.
                # `suspended_by`, the layers (a source's first part: "boost",
                # "manual") that set it aside while what they decide has an
                # end (Decision#ends).
                Entry = Data.define(:zone, :name, :bounds, :suspended_by) do
                    def initialize(zone:, name:, bounds:, suspended_by: [])
                        Guard.check(name, bounds)
                        super(zone:, name:, bounds:,
                              suspended_by: Guard.layers(name, suspended_by))
                    end

                    # Set aside under `below`: from a layer suspending it,
                    # and ending of itself (`ends`, not `until`, which a
                    # change queued ahead brings forward); one with no end
                    # never suspends it.
                    def suspended?(below)
                        !below.ends.nil? &&
                            suspended_by.include?(Guard.layer(below.source))
                    end
                end

                # A layer's name: a source's first part.
                LAYER = /\A[a-z][\w-]*\z/

                # A guard's bounds: a Setpoint, bounding something.
                def self.check(name, bounds)
                    unless bounds.is_a?(Setpoint)
                        raise Error, "guard #{name}: #{bounds.inspect} " \
                                     "is no band"
                    end
                    return unless bare?(bounds)
                    raise Error, "guard #{name} bounds nothing"
                end

                # The layers a guard is suspended by, as frozen names.
                def self.layers(name, given)
                    Array(given).map do |layer|
                        next layer.dup.freeze if layer.is_a?(String) &&
                                                 LAYER.match?(layer)
                        raise Error, "guard #{name}: #{layer.inspect} " \
                                     "is no layer"
                    end.freeze
                end

                def self.layer(source) = source.to_s.split(":", 2).first

                # No temperature side and no humidity bound.
                def self.bare?(setpoint)
                    setpoint.off? && (setpoint.humidity.nil? ||
                                      setpoint.humidity.none?)
                end
            end
        end
    end
end
