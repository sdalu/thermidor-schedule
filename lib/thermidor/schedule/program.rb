# frozen_string_literal: true

module Thermidor
    module Schedule
        # From `minute` (after midnight) on, `preset` is in force, with
        # `strategy` overriding the preset's own when given, and `on_time`
        # saying whether the change is wanted reached by then (true) or
        # only started then (false), nil leaving it to the preset; or,
        # holding no preset, `through` (one of THROUGH) lets another
        # program decide, with no strategy nor mark of its own.
        Transition = Data.define(:minute, :preset, :strategy, :through,
                                 :on_time) do
            def initialize(minute:, preset: nil, strategy: nil, through: nil,
                           on_time: nil)
                unless minute.is_a?(Integer) && minute.between?(0, 1439)
                    raise Error, "#{minute.inspect} is no minute of the day"
                end
                through = Transition.through(through, preset, strategy)
                Transition.check_on_time(on_time, preset, through)
                super(minute:, preset:, through:, on_time:,
                      strategy: Schedule.strategy(strategy))
            end

            def clock
                hour, min = minute.divmod(60)
                format("%<hour>02d:%<min>02d", hour:, min:)
            end
        end

        class Transition
            # `through` as a Symbol of THROUGH, nil for none; exactly one of
            # it and `preset` is given, and a strategy only with a preset.
            def self.through(through, preset, strategy)
                return check_preset(preset) if through.nil?
                word = through.to_s.to_sym if through.is_a?(String) ||
                                              through.is_a?(Symbol)
                unless THROUGH.include?(word)
                    raise Error, "#{through.inspect} is none of " \
                                 "#{THROUGH.join(", ")}"
                end
                raise Error, "#{word} holds no preset" if preset
                raise Error, "#{word} takes no strategy" if strategy
                word
            end

            # A mark is true, false or nil; a keyword takes none, and an
            # inline band, having no preset to leave it to, takes one.
            def self.check_on_time(on_time, preset, through)
                raise Error, "#{on_time.inspect} is no on-time mark" unless
                    [true, false, nil].include?(on_time)
                raise Error, "#{through} takes no on-time mark" if
                    through && !on_time.nil?
                return unless on_time.nil? && preset.is_a?(Preset) &&
                              preset.anonymous?
                raise Error, "an inline band says whether it is on time"
            end

            def self.check_preset(preset)
                raise Error, "a transition holds a preset or a keyword" unless
                    preset
                nil
            end
        end

        # A day template: transitions sorted by time of day. An anonymous
        # program (name nil) is written inline.
        Program = Data.define(:name, :transitions) do
            def initialize(transitions:, name: nil)
                raise Error, "usual is reserved, not a program name" if
                    name == "usual"
                sorted = transitions.sort_by(&:minute).freeze
                if sorted.map(&:minute).uniq.size != sorted.size
                    raise Error, "two transitions at the same time"
                end
                super(name:, transitions: sorted)
            end

            def label = name || "(inline)"

            # Last transition at or before `minute`, nil if none yet.
            def at(minute) = transitions.reverse.find { it.minute <= minute }

            # First transition strictly after `minute`, nil if none.
            def after(minute) = transitions.find { it.minute > minute }
        end
    end
end
