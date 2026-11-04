# frozen_string_literal: true

module Thermidor
    # What each zone should be doing over time. Decisions come from a
    # stack of layers (timetable at the bottom, then away, ...): the
    # highest active layer decides, and when it ends the one below takes
    # over again.
    module Schedule
        class Error      < StandardError; end
        class ParseError < Error; end

        # Minimum gap between the heat and cool setpoints, so that a
        # radiator and an aircon in the same zone never fight; the
        # default of Config#deadband.
        DEADBAND = 1.0

        DAY_MINUTES = 24 * 60

        # How the radiator and the aircon combine to hold a band; the
        # defaults of Config#strategies and Config#default_strategy.
        STRATEGIES       = %i[comfort cheapest quiet quick].freeze
        DEFAULT_STRATEGY = :comfort

        # nil stays nil (inherit); anything else must be a configured
        # strategy.
        def self.strategy(value)
            return if value.nil? || value.to_s.empty?
            name = value.to_sym
            known = config.strategies
            return name if known.include?(name)
            raise ParseError, "unknown strategy #{value} (#{known.join(", ")})"
        end

        # First strategy given, from the most specific level down.
        def self.resolve_strategy(*candidates)
            candidates.compact.first || config.default_strategy
        end
    end
end

require_relative "schedule/version"
require_relative "schedule/config"
require_relative "schedule/setpoint"
require_relative "schedule/preset"
require_relative "schedule/program"
require_relative "schedule/timetable"
require_relative "schedule/decision"
require_relative "schedule/stack"
require_relative "schedule/syntax"
require_relative "schedule/syntax/time"
require_relative "schedule/holidays"
require_relative "schedule/recurrence"
require_relative "schedule/recurrence/parser"
require_relative "schedule/recurrence/expansion"
require_relative "schedule/layers/timetable"
require_relative "schedule/layers/calendar"
require_relative "schedule/layers/away"
require_relative "schedule/layers/manual"
require_relative "schedule/layers/boost"
require_relative "schedule/layers/open_window"
require_relative "schedule/layers/clamp"
require_relative "schedule/steady"
require_relative "schedule/auto_away"
