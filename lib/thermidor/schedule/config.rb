# frozen_string_literal: true

module Thermidor
    module Schedule
        # The vocabulary of one process: the strategies a band may be held
        # by, the one given when none is, the least gap between the heat
        # and cool sides of a band, and whether a program change its
        # transition does not mark is wanted on time. Set once, at boot,
        # before any value is built: a value checks itself when built,
        # against the configuration of the time.
        Config = Data.define(:strategies, :default_strategy, :deadband,
                             :default_on_time) do
            def initialize(strategies:, default_strategy:, deadband:,
                           default_on_time:)
                strategies = Array(strategies).map { Config.name(it) }.freeze
                default_strategy = Config.name(default_strategy)
                deadband = Config.deadband(deadband)
                unless [true, false].include?(default_on_time)
                    raise Error, "default_on_time #{default_on_time.inspect} " \
                                 "is neither true nor false"
                end
                Config.check(strategies, default_strategy)
                super
            end

            # A strategy's name, a String or a Symbol, as a Symbol.
            def self.name(value)
                case value
                when String, Symbol then return value.to_sym
                end
                raise Error, "#{value.inspect} is no strategy name"
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
                          deadband: DEADBAND,
                          default_on_time: DEFAULT_ON_TIME)
        end

        @config = Config::DEFAULT

        class << self
            attr_reader :config

            # Changes the settings given, keeping the others; refused as a
            # whole, changing nothing, when they cannot hold together.
            def configure(**changes)
                unknown = changes.keys - Config.members
                raise Error, "unknown setting #{unknown.join(", ")}" if
                    unknown.any?
                @config = config.with(**changes)
            end
        end
    end
end
