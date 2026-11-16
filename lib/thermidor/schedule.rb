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

        # Whether a program change is wanted reached by its time when its
        # transition does not say; the default of Config#default_on_time.
        DEFAULT_ON_TIME = true

        # What a program transition may hold instead of a preset, letting
        # another program decide: the next one in the day's stack (pass), the
        # zone's weekday one (usual), or the fallback preset (fallback).
        THROUGH = %i[pass usual fallback].freeze

        # A name (a preset's, a program's, a special day's): ASCII and
        # lowercase, a letter first, so a name is never read as a band nor
        # as a transition's :by or :at, and reads the same in a source, a
        # URL and a terminal; then letters, digits, _ and -.
        NAME = /\A[a-z][a-z0-9_-]*\z/

        # Whether `text` is a NAME; bytes NAME cannot read (invalid, or an
        # encoding not keeping ASCII) are no name, not an encoding error.
        def self.name?(text)
            text.is_a?(String) && text.valid_encoding? &&
                text.encoding.ascii_compatible? && NAME.match?(text)
        end

        # Whether `value` gives a strategy: nil and "" give none.
        def self.strategy?(value) = !(value.nil? || value.to_s.empty?)

        # nil stays nil (inherit); anything else must be a configured
        # strategy.
        def self.strategy(value)
            return if value.nil? || value.to_s.empty?
            raise ParseError, "#{value.inspect} is no strategy" unless
                value.is_a?(String) || value.is_a?(Symbol)
            name = value.to_sym
            known = config.strategies
            return name if known.include?(name)
            raise ParseError, "unknown strategy #{value} (#{known.join(", ")})"
        end

        # First strategy given, from the most specific level down; one
        # outside the configured strategies (a built-in preset's, built
        # before them) counts as not given.
        def self.resolve_strategy(*candidates)
            known = config.strategies
            candidates.compact.find { known.include?(it) } ||
                config.default_strategy
        end
    end
end

require_relative "schedule/version"
require_relative "schedule/config"
require_relative "schedule/humidity"
require_relative "schedule/setpoint"
require_relative "schedule/preset"
require_relative "schedule/program"
require_relative "schedule/local_time"
require_relative "schedule/timetable"
require_relative "schedule/timetable/resolver"
require_relative "schedule/decision"
require_relative "schedule/stack"
require_relative "schedule/syntax"
require_relative "schedule/syntax/band"
require_relative "schedule/syntax/time"
require_relative "schedule/syntax/transition"
require_relative "schedule/holidays"
require_relative "schedule/recurrence"
require_relative "schedule/recurrence/parser"
require_relative "schedule/recurrence/expansion"
require_relative "schedule/layers/timetable"
require_relative "schedule/layers/calendar"
require_relative "schedule/layers/calendar/entry"
require_relative "schedule/layers/calendar/stretch"
require_relative "schedule/layers/calendar/seen"
require_relative "schedule/layers/away"
require_relative "schedule/layers/manual"
require_relative "schedule/layers/boost"
require_relative "schedule/layers/open_window"
require_relative "schedule/layers/guard_entry"
require_relative "schedule/layers/guard_span"
require_relative "schedule/layers/guard"
require_relative "schedule/layers/clamp"
require_relative "schedule/steady"
require_relative "schedule/auto_away"
