# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # A short push on a zone, above any manual setting: a preset for
            # some minutes. Without one, the entry's mode says which push
            # was asked for, and so which default preset: :both (boost),
            # :heat (boost-heat) or :cool (boost-cool).
            class Boost < Manual
                NOUN = "a boost"
                # A boost is short: it always has an end of its own, a
                # duration.
                MODES = %i[for].freeze

                DIRECTIONS = %i[both heat cool].freeze

                # How long a boost lasts when not told, and at most, in
                # seconds, as configured.
                def self.duration = Schedule.config.boost_duration
                def self.longest  = Schedule.config.boost_longest

                # The built-in preset of each direction, for the settings in
                # force.
                def self.defaults
                    { both: Preset.boost, heat: Preset.boost_heat,
                      cool: Preset.boost_cool }
                end

                # defaults: { direction => Preset }, the built-in ones for
                # any not given.
                def initialize(entries, defaults: {})
                    @defaults = Boost.defaults.merge(defaults)
                    super(entries, source: "boost")
                end

                private

                def default_for(entry)
                    @defaults.fetch(entry.mode) { @defaults[:both] }
                end
            end
        end
    end
end
