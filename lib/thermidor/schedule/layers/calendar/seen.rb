# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            class Calendar
                # What the calendar shows of a zone's days: its own
                # Resolution, or, where nothing is in force through it (and
                # the layer passes the decision below), the weekday
                # timetable's, as the timetable layer decides it. A layer of
                # the caller's own between the two is not seen.
                class Seen
                    def initialize(own, plain)
                        @own   = own
                        @plain = plain
                    end

                    def at(time)
                        found = @own.at(time)
                        found.chain.empty? ? @plain.at(time) : found
                    end

                    def next_change(time)
                        own = @own.next_change(time)
                        return own unless @own.at(time).chain.empty?
                        [own, @plain.next_change(time)].compact.min
                    end
                end
            end
        end
    end
end
