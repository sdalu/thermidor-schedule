# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # A window is open: the zone holds the preset named open-window
            # (frost protection by default) above all but guards and clamp,
            # for some minutes, or (mode :steady) until the temperature
            # steadies, with an end time as a safety limit.
            class OpenWindow < Manual
                NOUN = "an open window"
                # A window is held for a while, or until the room steadies,
                # with a limit: never until cleared, nor to a change below.
                MODES = %i[for steady].freeze

                # The safety limit of a :steady window when not told, and
                # the longest a window may be held for, in seconds, as
                # configured.
                def self.limit   = Schedule.config.open_window_limit
                def self.longest = Schedule.config.open_window_longest

                def initialize(entries, default: Preset.open_window)
                    super(entries, source: "open-window", default:)
                end
            end
        end
    end
end
