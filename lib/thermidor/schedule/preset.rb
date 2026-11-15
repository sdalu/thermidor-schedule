# frozen_string_literal: true

module Thermidor
    module Schedule
        # A setpoint with an optional default strategy and description.
        # Named presets are shared; an anonymous one (name nil) is written
        # inline.
        Preset = Data.define(:name, :setpoint, :strategy, :description) do
            def initialize(setpoint:, name: nil, strategy: nil,
                           description: nil)
                Preset.check_name(name)
                super(name:, setpoint:, strategy: Schedule.strategy(strategy),
                      description:)
            end

            def anonymous? = name.nil?
            def label      = name || setpoint.to_s
        end

        class Preset
            # nil (anonymous) or a NAME, not one of THROUGH's keywords.
            def self.check_name(name)
                return if name.nil?
                raise Error, "#{name.inspect} is no preset name" unless
                    Schedule.name?(name)
                raise Error, "#{name} is reserved, not a preset name" if
                    THROUGH.map(&:to_s).include?(name)
            end

            # The presets the layers fall back on when given no preset, as
            # data: a band built before Schedule.configure need not hold
            # the deadband configured after, so they are built for the
            # settings in force when asked (Preset.system).
            BUILT_IN = [
                { name: "frost", heat: 7,
                  description: "frost protection only" },
                { name: "away", strategy: :cheapest, heat: 16, cool: 30,
                  description: "nobody home" },
                { name: "boost", strategy: :quick, heat: 23, cool: 24,
                  description: "a short push, either way" },
                { name: "boost-heat", strategy: :quick, heat: 24,
                  description: "a short push of heat" },
                { name: "boost-cool", strategy: :quick, cool: 22,
                  description: "a short push of cold" },
                { name: "open-window", heat: 7,
                  description: "a window is open" }
            ].freeze

            # The built-in presets, for the settings in force: a store
            # keeping them should let them be changed but not deleted.
            def self.system
                config = Schedule.config
                return @system.last if @system&.first.equal?(config)
                @system = [config, BUILT_IN.map { built(**it) }.freeze]
                @system.last
            end

            def self.frost       = named("frost")
            def self.away        = named("away")
            def self.boost       = named("boost")
            def self.boost_heat  = named("boost-heat")
            def self.boost_cool  = named("boost-cool")
            def self.open_window = named("open-window")

            def self.named(name) = system.find { it.name == name }

            # Sides closer than the deadband configured give way as the
            # clamp's do (the cool side up); a strategy not configured is
            # left out, the zone's or the default then applying.
            def self.built(name:, description:, heat: nil, cool: nil,
                           strategy: nil)
                heat, cool = Layers::Clamp.separate(heat, cool, nil) if
                    heat && cool
                strategy = nil unless
                    Schedule.config.strategies.include?(strategy)
                new(name:, description:, strategy:,
                    setpoint: Setpoint.new(heat:, cool:))
            end
        end
    end
end
