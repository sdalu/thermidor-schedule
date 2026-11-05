# frozen_string_literal: true

module Thermidor
    module Schedule
        # Whether an open window has been shut again, from the readings of
        # the room since it was opened, which must go through, in order:
        #
        # - a move: `change` °C away from the baseline (down while
        #   heating, up while cooling), as far as it goes; the baseline is
        #   the last reading at or before the opening, else the first
        #   after;
        # - a rebound: back from that extreme by the fraction `rebound` of
        #   the move (a half: 1 °C back after a 2 °C dip), the window being
        #   shut while the device still works;
        # - a settling: from the rebound on, the readings of the last
        #   `span` seconds all within `tolerance` °C;
        #
        # and the window must have been open at least `after` seconds.
        # Requiring the move keeps a room that barely reacts, on a mild
        # day, from looking shut while its window is still open; requiring
        # the rebound keeps a room that has cooled as far as it will from
        # looking shut when it merely stopped moving.
        #
        # Thresholds are met exactly too: readings at the tenth make
        # differences such as 20.6 - 20.4 = 0.20000000000000284, so each
        # comparison allows for MARGIN, far below any reading's precision.
        Steady = Data.define(:span, :tolerance, :change, :rebound,
                             :after) do
            def initialize(span: 600, tolerance: 0.2, change: 2.0,
                           rebound: 0.5, after: 900)
                super
            end

            # readings: [[Time, °C], ...] in any order; opened: the Time the
            # window was opened.
            def steady?(readings, opened)
                sorted = readings.sort_by(&:first)
                since  = sorted.select { |time, _| time >= opened }
                return false if since.empty?
                return false if since.last.first - opened < after
                first = baseline(sorted, opened) || since.first.last
                rebound_at = rebound_time(since, first) or return false
                settled?(since, rebound_at)
            end

            private

            # The room as the window opened: the last reading at or before
            # `opened`, nil if none.
            def baseline(sorted, opened)
                sorted.reverse.find { |time, _| time <= opened }&.last
            end

            # When the readings, having moved by `change` from `first`, came
            # back from their extreme by `rebound` of the move; nil if not
            # yet.
            def rebound_time(since, first)
                moved = since.index do |_, value|
                    (value - first).abs >= change - Steady::MARGIN
                end
                moved && turn_back(since.drop(moved), first)
            end

            # Follows the move out to its extreme, until a reading comes
            # back from it by `rebound` of the way out.
            def turn_back(rest, first)
                extreme   = rest.first.last
                direction = extreme <=> first
                rest.each do |time, value|
                    back = (extreme - value) * direction
                    need = rebound * (extreme - first).abs
                    return time if back >= need - Steady::MARGIN
                    extreme = value if back.negative?
                end
                nil
            end

            # The values from `start` on, the one in force then first.
            def window(since, start)
                held = since.reverse.find { |time, _| time <= start }
                [held.last] + since.filter_map do |time, value|
                    value if time > start
                end
            end

            # From `rebound_at` on, the last `span` seconds are covered and
            # spread by no more than `tolerance`, counting what was in force
            # when they began: the last reading at or before their start,
            # so a sensor read less often than `span` is held to it too.
            def settled?(since, rebound_at)
                start = since.last.first - span
                return false if rebound_at > start
                values = window(since, start)
                values.max - values.min <= tolerance + Steady::MARGIN
            end
        end

        class Steady
            MARGIN = 1e-6
        end
    end
end
