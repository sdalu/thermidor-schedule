# frozen_string_literal: true

module Thermidor
    module Schedule
        module Layers
            # A short push on a zone, above any manual setting: a preset for
            # some minutes. Without one, the entry's mode says which push
            # was asked for, and so which default preset: :both (boost),
            # :heat (boost-heat) or :cool (boost-cool).
            class Boost < Manual
                # How long a boost lasts when not told, and at most, in
                # seconds.
                DEFAULT = 30 * 60
                LONGEST = 60 * 60

                DIRECTIONS = %i[both heat cool].freeze

                DEFAULTS = { both: Preset::BOOST, heat: Preset::BOOST_HEAT,
                             cool: Preset::BOOST_COOL }.freeze

                # defaults: { direction => Preset }, the built-in ones for
                # any not given.
                def initialize(entries, defaults: {})
                    @defaults = DEFAULTS.merge(defaults)
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
