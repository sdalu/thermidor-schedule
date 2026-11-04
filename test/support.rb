# frozen_string_literal: true

# Builders for schedule tests: presets, programs and local times.
module ScheduleSupport
    Schedule = Thermidor::Schedule

    COMFORT = Schedule::Preset.new(
        name: "comfort", setpoint: Schedule::Setpoint.new(heat: 21, cool: 25)
    )
    ECO = Schedule::Preset.new(
        name: "eco", strategy: :cheapest,
        setpoint: Schedule::Setpoint.new(heat: 18, cool: 28)
    )
    NIGHT = Schedule::Preset.new(
        name: "night", strategy: :quiet,
        setpoint: Schedule::Setpoint.new(heat: 17, cool: 27)
    )

    # program("workday", "06:30" => COMFORT, "08:30" => [ECO, :quick])
    def program(name, steps)
        transitions = steps.map do |clock, (preset, strategy)|
            Schedule::Transition.new(minute: Schedule::Syntax.minute(clock),
                                     preset:, strategy:)
        end
        Schedule::Program.new(name:, transitions:)
    end

    def at(text) = Schedule::Syntax.time(text)

    # A zone running the same workday program every day.
    def workday_zone(strategy: nil)
        workday = program("workday", "06:30" => [COMFORT, :quick],
                                     "08:30" => ECO, "22:30" => NIGHT)
        days = (0..6).to_h { [it, workday] }
        Schedule::Zone.new(name: "salon", strategy:,
                           timetable: Schedule::Timetable.new(days:))
    end

    def base(fallback = Schedule::Preset::FROST)
        Schedule::Layers::Timetable.new(fallback:)
    end

    def resolve(text, zone: @zone, layers: [base])
        Schedule::Stack.new(layers).resolve(zone, at(text))
    end

    # Runs the block with the local time zone set to `zone`.
    def in_zone(zone)
        saved = ENV.fetch("TZ", nil)
        ENV["TZ"] = zone
        yield
    ensure
        ENV["TZ"] = saved
    end
end
