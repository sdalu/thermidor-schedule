# frozen_string_literal: true

module Thermidor
    module Schedule
        # A comfort band: heat below `heat`, cool above `cool`; nil on a
        # side means never act on that side, nil on both means off.
        Setpoint = Data.define(:heat, :cool) do
            def initialize(heat: nil, cool: nil)
                heat, cool = [heat, cool].map do |degrees|
                    degrees&.then { Setpoint.degrees(it) }
                end
                if heat && cool && (cool - heat).round(1) < DEADBAND
                    raise Error, "heat #{heat} must be at least " \
                                 "#{DEADBAND} below cool #{cool}"
                end
                super
            end

            # A finite temperature, to the tenth.
            def self.degrees(value)
                degrees = Float(value, exception: false)
                raise Error, "#{value.inspect} is no temperature" unless
                    degrees&.finite?
                degrees.round(1)
            end

            def off? = heat.nil? && cool.nil?

            # The inline-preset notation: "+21.0..+25.0", "+7.0..", "off".
            def to_s
                return "off" if off?
                [heat, cool].map { it && format("%+.1f", it) }.join("..")
            end
        end
    end
end
