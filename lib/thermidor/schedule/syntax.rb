# frozen_string_literal: true

module Thermidor
    module Schedule
        # The text forms used on the command line. References to named
        # presets and programs come back as their name (a String), inline
        # ones as an anonymous Preset or Program.
        #
        #   preset    comfort  +20.5..+25  +5..  ..+26  off  (then /quick)
        #   program   workday  06:30=comfort,22:30=+17..+27/quiet  usual
        #   days      mon  mon-fri  sat,sun   (or a special day: holiday)
        #
        # Dates, times and durations are in syntax/time.rb.
        module Syntax
            NUMBER   = /[+-]\d+(?:\.\d)?/
            BAND     = /\A(?<heat>#{NUMBER})?\.\.(?<cool>#{NUMBER})?\z/
            NAME     = /\A[a-z][\w-]*\z/
            CLOCK    = /\A(?<hour>\d{1,2}):(?<min>\d{2})\z/
            WEEKDAYS = %w[sun mon tue wed thu fri sat].freeze
            FULL_DAYS = %w[sunday monday tuesday wednesday thursday friday
                           saturday].freeze

            module_function

            # "comfort/quick" => ["comfort", :quick]
            def preset_ref(text)
                body, strategy, *rest = text.split("/", -1)
                raise ParseError, "bad preset #{text.inspect}" unless
                    body && rest.empty? && strategy != ""
                [preset(body), strategy && Schedule.strategy(strategy)]
            end

            # A name, or an anonymous Preset for "off" and band literals.
            def preset(text)
                return Preset.new(setpoint: Setpoint.new) if text == "off"
                return name(text) unless text.start_with?("+", "-", ".")
                Preset.new(setpoint: band(text))
            end

            # "+20.5..+25" => Setpoint; at least one side is required.
            def band(text)
                heat, cool = BAND.match(text)&.values_at(:heat, :cool)
                raise ParseError, "bad band #{text.inspect}" unless
                    heat || cool
                Setpoint.new(heat: heat&.to_f, cool: cool&.to_f)
            end

            def name(text)
                return text if NAME.match?(text)
                raise ParseError, "bad name #{text.inspect}"
            end

            # A name, an anonymous Program for "06:30=x,22:30=y", or
            # Timetable::USUAL for the keyword "usual".
            def program(text)
                return Timetable::USUAL if text == "usual"
                return name(text) unless text.include?("=")
                Program.new(transitions: text.split(",").map { transition(it) })
            end

            # "06:30=comfort/quick" => Transition, preset possibly a name.
            def transition(text)
                clock, value = text.split("=", 2)
                raise ParseError, "bad transition #{text.inspect}" unless value
                preset, strategy = preset_ref(value)
                Transition.new(minute: minute(clock), preset:, strategy:)
            end

            def minute(text)
                match = CLOCK.match(text)
                hour, min = match&.values_at(:hour, :min)&.map(&:to_i)
                raise ParseError, "bad time #{text.inspect}" unless
                    hour && hour < 24 && min < 60
                (hour * 60) + min
            end

            # "mon-fri" or "sat,sun" => [1, 2, 3, 4, 5] or [6, 0]
            def days(text)
                text.split(",").flat_map { day_range(it) }.uniq
            end

            def day_range(text)
                first, last = text.split("-", 2).map { weekday(it) }
                return [first] unless last
                (0..((last - first) % 7)).map { (first + it) % 7 }
            end

            def weekday(text)
                weekday_index(text) or
                    raise ParseError, "bad weekday #{text.inspect}"
            end

            def weekday_index(text)
                WEEKDAYS.index(text.downcase) || FULL_DAYS.index(text.downcase)
            end

            # Weekdays as for #days, or else the name of a special day.
            def day_keys(text)
                weekdays = text.split(/[,-]/).all? { weekday_index(it) }
                weekdays ? days(text) : [name(text)]
            end

            # A kind of day for the calendar: "sun" for any weekday
            # spelling, or the name of a special day.
            def day_kind(text)
                index = weekday_index(text)
                index ? WEEKDAYS[index] : name(text)
            end
        end
    end
end
