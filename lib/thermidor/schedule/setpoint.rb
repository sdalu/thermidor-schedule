# frozen_string_literal: true

module Thermidor
    module Schedule
        # A comfort band: heat below `heat`, cool above `cool`; nil on a
        # side means never act on that side, nil on both means off. The
        # sides are at least the configured deadband apart. `humidity`,
        # Humidity bounds or nil for none given (the bounds below kept).
        Setpoint = Data.define(:heat, :cool, :humidity) do
            def initialize(heat: nil, cool: nil, humidity: nil)
                heat, cool = [heat, cool].map do |degrees|
                    degrees&.then { Setpoint.degrees(it) }
                end
                Setpoint.check(heat, cool, humidity)
                super
            end

            def self.check(heat, cool, humidity)
                gap = Schedule.config.deadband
                if heat && cool && (cool - heat).round(1) < gap
                    raise Error, "heat #{heat} must be at least " \
                                 "#{gap} below cool #{cool}"
                end
                return if humidity.nil? || humidity.is_a?(Humidity)
                raise Error, "#{humidity.inspect} is no humidity bounds"
            end

            # A finite temperature, to the tenth.
            def self.degrees(value)
                degrees = Float(value, exception: false)
                raise Error, "#{value.inspect} is no temperature" unless
                    degrees&.finite?
                degrees.round(1)
            end

            # No temperature side: humidity bounds may remain.
            def off? = heat.nil? && cool.nil?

            # The inline-preset notation: "+21.0..+25.0", "+7.0..", "off",
            # then any humidity bounds: "+20.0..+26.0@..60", "off@" (none).
            def to_s
                band = if off? then "off"
                       else [heat, cool].map { it && format("%+.1f", it) }
                                        .join("..")
                       end
                humidity ? "#{band}@#{humidity}" : band
            end
        end
    end
end
