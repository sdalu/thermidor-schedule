# frozen_string_literal: true

module Thermidor
    module Schedule
        # The house's settings, one process's: the strategies a band may be
        # held by, the one given when none is, the least gap between the
        # heat and cool sides of a band, whether a program change its
        # transition does not mark is wanted on time, the limits the clamp
        # keeps both sides within, how long a setting by hand may last
        # (seconds), when everyone gone starts an automatic away (seconds),
        # and when an open window's room counts as steady again (Steady's
        # thresholds). Set once, at boot, before any value is built: a
        # value checks itself when built, against the configuration of the
        # time, and a layer or rule built without an argument takes the
        # setting then in force.
        Config = Data.define(
            :strategies, :default_strategy, :deadband, :default_on_time,
            :clamp_limits,
            :manual_longest, :boost_duration, :boost_longest,
            :open_window_limit, :open_window_longest,
            :auto_away_leave,
            :steady_span, :steady_tolerance, :steady_change, :steady_rebound,
            :steady_after
        ) do
            def initialize(**settings)
                missing = Config.members - settings.keys
                raise ArgumentError, "missing #{missing.join(", ")}" if
                    missing.any?
                super(**Config.checked(settings))
            end
        end

        class Config
            # The durations of settings by hand, in seconds: a longest is
            # more than nothing, and what a kind lasts when not told is
            # within its longest.
            DURATIONS = %i[manual_longest boost_duration boost_longest
                           open_window_limit open_window_longest].freeze

            # Steady's thresholds: seconds, °C, and a fraction of the move.
            STEADY = %i[steady_span steady_tolerance steady_change
                        steady_rebound steady_after].freeze

            # `settings` checked, each in its own form.
            def self.checked(settings)
                settings = normalized(settings)
                check(settings[:strategies], settings[:default_strategy])
                check_on_time(settings[:default_on_time])
                check_limits(settings[:clamp_limits], settings[:deadband])
                check_durations(settings)
                check_leave(settings[:auto_away_leave])
                check_steady(settings)
                settings
            end

            # The strategies and the default one as Symbols, the deadband
            # to the tenth.
            def self.normalized(settings)
                strategies = Array(settings[:strategies]).map { name(it) }
                settings.merge(
                    strategies: strategies.freeze,
                    default_strategy: name(settings[:default_strategy]),
                    deadband: deadband(settings[:deadband])
                )
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

            def self.check_on_time(value)
                return if [true, false].include?(value)
                raise Error, "default_on_time #{value.inspect} is neither " \
                             "true nor false"
            end

            # Limits narrower than `gap` (to the tenth, as a setpoint's
            # sides), backwards, of no numbers, open-ended or excluding
            # their end would hold no band.
            def self.limits?(limits, gap)
                limits.is_a?(Range) && !limits.exclude_end? &&
                    [limits.begin, limits.end].all?(Numeric) &&
                    (limits.end - limits.begin).round(1) >= gap
            end

            def self.check_limits(limits, gap)
                return if limits?(limits, gap)
                raise Error, "limits #{limits.inspect} hold no band"
            end

            def self.check_durations(settings)
                DURATIONS.each do |key|
                    value = settings[key]
                    raise Error, "#{key} #{value.inspect} is no duration" unless
                        value.is_a?(Integer) && value.positive?
                end
                within(settings, :boost_duration, :boost_longest)
                within(settings, :open_window_limit, :open_window_longest)
            end

            # Seconds, none at all meaning at once.
            def self.check_leave(leave)
                return if leave.is_a?(Integer) && !leave.negative?
                raise Error, "auto_away_leave #{leave.inspect} is no delay"
            end

            def self.within(settings, key, longest)
                return if settings[key] <= settings[longest]
                raise Error, "#{key} #{settings[key]} is over #{longest} " \
                             "#{settings[longest]}"
            end

            # Finite and not below zero; the rebound, a fraction, at most 1.
            def self.check_steady(settings)
                STEADY.each do |key|
                    value = settings[key]
                    next if value.is_a?(Numeric) && value.finite? &&
                            !value.negative? &&
                            (key != :steady_rebound || value <= 1)
                    raise Error, "#{key} #{value.inspect} is out of range"
                end
            end

            DEFAULT = new(strategies: STRATEGIES,
                          default_strategy: DEFAULT_STRATEGY,
                          deadband: DEADBAND,
                          default_on_time: DEFAULT_ON_TIME,
                          clamp_limits: 5.0..30.0,
                          manual_longest: 12 * 3600,
                          boost_duration: 30 * 60,
                          boost_longest: 60 * 60,
                          open_window_limit: 60 * 60,
                          open_window_longest: 2 * 60 * 60,
                          auto_away_leave: 20 * 60,
                          steady_span: 600,
                          steady_tolerance: 0.2,
                          steady_change: 2.0,
                          steady_rebound: 0.5,
                          steady_after: 900)
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
