# frozen_string_literal: true

module Thermidor
    module Schedule
        # The text form of a program's transition:
        #
        #   06:30=comfort  06:30=comfort/quick  22:00=+17..+27/quiet
        #   22:00=pass  22:00=usual  22:00=fallback   (keywords of THROUGH)
        #   06:30=comfort:by  22:00=+17..+27:at   (on_time: reached by the
        #   time, or started at it; before or after a /STRATEGY)
        module Syntax
            # The marks a transition may end with, and the on_time each sets.
            ON_TIME = { ":by" => true, ":at" => false }.freeze

            module_function

            # "06:30=comfort/quick" => Transition, preset possibly a name;
            # "22:00=pass" one holding a keyword of THROUGH instead; a
            # an ON_TIME mark sets on_time ("+20..+25:by").
            def transition(text)
                text!(text)
                clock, value = text.split("=", 2)
                raise ParseError, "bad transition #{text.inspect}" unless value
                value, on_time = on_time(value)
                preset, strategy = preset_ref(value)
                minute = minute(clock)
                as_parsed do
                    built_transition(minute, preset, strategy, on_time)
                end
            end

            # [the value without its mark, the mark's on_time or nil]. The
            # /STRATEGY and the mark follow the preset in either order (no
            # name nor band holds a / or a :); a mark not of ON_TIME, or
            # two, is said so rather than refused as a bad name.
            def on_time(value)
                preset, *parts = value.split(%r{(?=[/:])})
                marks, strategy = parts.partition { it.start_with?(":") }
                unless marks.size <= 1 && marks.all? { ON_TIME.key?(it) }
                    raise ParseError, "bad mark in #{value.inspect}: " \
                                      "one :by or :at"
                end
                [[preset, *strategy].join, marks.first && ON_TIME[marks.first]]
            end

            def built_transition(minute, preset, strategy, on_time)
                if THROUGH.map(&:to_s).include?(preset)
                    return Transition.new(minute:, through: preset, strategy:,
                                          on_time:)
                end
                Transition.new(minute:, preset:, strategy:, on_time:)
            end
        end
    end
end
