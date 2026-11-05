# frozen_string_literal: true

module Thermidor
    module Schedule
        # A local clock reading on a date made a moment, the same for the
        # timetable's transitions and for a time typed (Syntax.time).
        module LocalTime
            module_function

            # Local wall-clock time. One the clocks skip, going forward, is
            # the moment they jump (02:30 is 03:00), so moments keep the
            # order of clock readings; of one that comes twice, when they
            # go back, the first.
            def at(date, minute)
                hour, min = minute.divmod(60)
                time = Time.new(date.year, date.month, date.day, hour, min)
                return jump(time) if time.to_date != date ||
                                     (time.hour * 60) + time.min != minute
                first_of(time)
            end

            # Of a clock reading that comes twice, as clocks go back (an
            # hour, or half an hour on Lord Howe), the first; Time.new gives
            # the second.
            def first_of(time)
                shift   = (time - (3 * 3600)).utc_offset - time.utc_offset
                earlier = time - shift
                return time unless shift.positive?
                same = earlier.hour == time.hour && earlier.min == time.min
                same ? earlier : time
            end

            # Of a clock reading that comes twice (time, its first pass),
            # the second; nil for one that comes once.
            def second_of(time)
                shift = time.utc_offset - (time + (3 * 3600)).utc_offset
                return unless shift.positive?
                later = time + shift
                later if later.hour == time.hour && later.min == time.min
            end

            # The moment the clocks jumped forward, before `time`, which
            # Time.new moved past the gap.
            def jump(time)
                time -= 60 while (time - 60).utc_offset == time.utc_offset
                time
            end
        end
    end
end
