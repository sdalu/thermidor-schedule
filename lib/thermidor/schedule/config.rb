# frozen_string_literal: true

module Thermidor
    module Schedule
        # The vocabulary of one process: the strategies a band may be held
        # by, the one given when none is, and the least gap between the
        # heat and cool sides of a band. Set once, at boot, before any
        # value is built: a value checks itself when built, against the
        # configuration of the time.
        Config = Data.define(:strategies, :default_strategy, :deadband) do
            def initialize(strategies:, default_strategy:, deadband:)
                strategies = Array(strategies).map(&:to_sym).freeze
                default_strategy = default_strategy.to_sym
                deadband = Config.deadband(deadband)
                Config.check(strategies, default_strategy)
                super
            end

            # A finite gap, to the tenth, not below zero.
            def self.deadband(value)
                gap = Float(value, exception: false)
                return gap.round(1) if gap&.finite? && !gap.negative?
                raise Error, "deadband #{value.inspect} is no gap"
            end

            def self.check(names, default)
                raise Error, "no strategy" if names.empty?
                raise Error, "a strategy twice" unless names.uniq == names
                return if names.include?(default)
                raise Error, "default strategy #{default} is none of " \
                             "#{names.join(", ")}"
            end
        end

        class Config
            DEFAULT = new(strategies: STRATEGIES,
                          default_strategy: DEFAULT_STRATEGY,
                          deadband: DEADBAND)
        end

        @config = Config::DEFAULT

        class << self
            attr_reader :config

            # Changes the settings given, keeping the others; refused as a
            # whole, changing nothing, when they cannot hold together.
            def configure(**changes)
                @config = config.with(**changes)
            end
        end
    end
end
