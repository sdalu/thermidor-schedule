# frozen_string_literal: true

require "test_helper"
require "support"

# Each kind of hand-made setting ends in the modes it means: a manual
# setting :for, :next or :forever; a boost :for; an open window :for or
# :steady. Another kind's mode is refused with ArgumentError, naming the
# kind; a mode no kind knows with Error.
class EndModesTest < Minitest::Test
    include ScheduleSupport

    Layers = Schedule::Layers
    NOW = Time.new(2026, 11, 5, 10, 0, 0, "+01:00")

    def test_each_kind_takes_its_own_modes
        assert_equal NOW + 600, ends(Layers::Manual, :for)
        assert_equal NOW + 600, ends(Layers::Boost, :for)
        assert_equal NOW + 600, ends(Layers::OpenWindow, :for)
        assert_equal NOW + 600, ends(Layers::OpenWindow, :steady)
        assert_nil ends(Layers::Manual, :forever)
    end

    def test_another_kind_s_mode_is_refused_naming_the_kind
        { Layers::Manual => %i[steady],
          Layers::Boost => %i[steady next forever],
          Layers::OpenWindow => %i[next forever] }.each do |kind, modes|
            modes.each { refused(kind, it) }
        end
    end

    def test_a_mode_no_kind_knows_is_an_error
        assert_raises(Schedule::Error) { ends(Layers::Manual, :someday) }
    end

    private

    def refused(kind, mode)
        error = assert_raises(ArgumentError, "#{kind} #{mode}") do
            ends(kind, mode)
        end
        assert_match(/#{kind::NOUN} takes no :#{mode} end/, error.message)
    end

    def ends(kind, mode)
        kind.ends_at(mode, below: nil, zone: nil, now: NOW, duration: 600)
    end
end
