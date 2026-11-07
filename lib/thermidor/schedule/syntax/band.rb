# frozen_string_literal: true

module Thermidor
    module Schedule
        # The text form of a band: its temperature sides, then any humidity
        # bounds after "@".
        #
        #   sides     +20.5..+25  +5..  ..+26  off
        #   humidity  @30..60  @..60  @30..  @60 (a ceiling)  @ (cleared)
        #   guard     +15..+25@40..65  +7..  @..65 (no sides)
        module Syntax
            NUMBER   = /[+-]\d+(?:\.\d)?/
            BAND     = /\A(?<heat>#{NUMBER})?\.\.(?<cool>#{NUMBER})?\z/
            PERCENT  = /\d+(?:\.\d)?/
            HUMIDITY = /\A(?:(?<low>#{PERCENT})?\.\.)?(?<high>#{PERCENT})?\z/

            module_function

            # "+20.5..+25", "off@..60" => Setpoint; at least one side, or
            # "off".
            def band(text)
                text!(text)
                temperature, bounds = text.split("@", 2)
                found = sides(temperature) or
                    raise ParseError, "bad band #{text.inspect}"
                heat, cool = found
                as_parsed do
                    Setpoint.new(heat:, cool:,
                                 humidity: bounds&.then { humidity(it) })
                end
            end

            # A guard's bounds: a band whose sides may be left out before
            # its humidity, "+15..+25@40..65", "+7..", "@..65" => Setpoint.
            # One bounding nothing ("off", "@") is refused.
            def guard(text)
                text!(text)
                setpoint = band(text.start_with?("@") ? "off#{text}" : text)
                return setpoint unless Layers::Guard.bare?(setpoint)
                raise ParseError, "guard #{text.inspect} bounds nothing"
            end

            # [heat, cool] for "+20.5..+25" or "off"; nil if neither.
            def sides(text)
                return [nil, nil] if text == "off"
                heat, cool = BAND.match(text)&.values_at(:heat, :cool)
                [heat&.to_f, cool&.to_f] if heat || cool
            end

            # "30..60", "..60", "30..", "60" (a ceiling) => Humidity; ""
            # => Humidity::NONE, the bounds cleared.
            def humidity(text)
                text!(text)
                return Humidity::NONE if text.empty?
                low, high = HUMIDITY.match(text)&.values_at(:low, :high)
                raise ParseError, "bad humidity #{text.inspect}" unless
                    low || high
                as_parsed { Humidity.new(low: low&.to_f, high: high&.to_f) }
            end
        end
    end
end
