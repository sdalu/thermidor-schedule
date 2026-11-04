# frozen_string_literal: true

module Thermidor
    module Schedule
        # A setpoint with an optional default strategy and description.
        # Named presets are shared; an anonymous one (name nil) is written
        # inline.
        Preset = Data.define(:name, :setpoint, :strategy, :description) do
            def initialize(setpoint:, name: nil, strategy: nil,
                           description: nil)
                super(name:, setpoint:, strategy: Schedule.strategy(strategy),
                      description:)
            end

            def anonymous? = name.nil?
            def label      = name || setpoint.to_s
        end

        # The defaults the layers fall back on when given no preset.
        class Preset
            FROST = new(name: "frost", setpoint: Setpoint.new(heat: 7),
                        description: "frost protection only")
            AWAY  = new(name: "away", strategy: :cheapest,
                        setpoint: Setpoint.new(heat: 16, cool: 30),
                        description: "nobody home")
            BOOST = new(name: "boost", strategy: :quick,
                        setpoint: Setpoint.new(heat: 23, cool: 24),
                        description: "a short push, either way")
            BOOST_HEAT = new(name: "boost-heat", strategy: :quick,
                             setpoint: Setpoint.new(heat: 24),
                             description: "a short push of heat")
            BOOST_COOL = new(name: "boost-cool", strategy: :quick,
                             setpoint: Setpoint.new(cool: 22),
                             description: "a short push of cold")
            OPEN_WINDOW = new(name: "open-window",
                              setpoint: Setpoint.new(heat: 7),
                              description: "a window is open")

            # The presets the layers fall back on: a store keeping them should
            # let them be changed but not deleted.
            SYSTEM = [FROST, AWAY, BOOST, BOOST_HEAT, BOOST_COOL,
                      OPEN_WINDOW].freeze
        end
    end
end
