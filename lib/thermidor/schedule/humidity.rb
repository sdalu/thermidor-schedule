# frozen_string_literal: true

module Thermidor
    module Schedule
        # Relative humidity bounds on a band, in %: a floor (`low`), a
        # ceiling (`high`), either nil for none. A band without them
        # (Setpoint#humidity nil) keeps the bounds below it; NONE, both
        # nil, clears them on purpose.
        Humidity = Data.define(:low, :high) do
            def initialize(low: nil, high: nil)
                low, high = [low, high].map do |percent|
                    percent&.then { Humidity.percent(it) }
                end
                if low && high && low >= high
                    raise Error, "humidity floor #{low} must be below " \
                                 "ceiling #{high}"
                end
                super
            end

            # A relative humidity, 0 to 100, to the tenth.
            def self.percent(value)
                percent = Float(value, exception: false)
                raise Error, "#{value.inspect} is no relative humidity" unless
                    percent && (0..100).cover?(percent)
                percent.round(1)
            end

            def none? = low.nil? && high.nil?

            # The inline notation after a band's "@": "30..60", "..60",
            # "30..", and "" for none.
            def to_s
                return "" if none?
                [low, high].map { it && format("%g", it) }.join("..")
            end
        end

        class Humidity
            NONE = new
        end
    end
end
