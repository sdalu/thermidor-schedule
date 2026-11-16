# frozen_string_literal: true

module Thermidor
    module Schedule
        # When an automatic away period starts, from everyone's presence:
        # everyone away for `leave` seconds (auto_away_leave as configured
        # unless given). A status answers `since`, the Time its state
        # began, and `close?`, whether its person is home or as good as
        # (not known to be away, or near on the way back).
        AutoAway = Data.define(:leave) do
            def initialize(leave: Schedule.config.auto_away_leave)
                super
            end

            # The start time, or nil while someone is, or may be, home.
            def start(statuses)
                return if statuses.empty? || statuses.any?(&:close?)
                statuses.map(&:since).max + leave
            end
        end
    end
end
