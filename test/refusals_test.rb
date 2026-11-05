# frozen_string_literal: true

require "test_helper"

# What is not text, a time of day or a range of limits is refused with
# the gem's own errors, not a Ruby error from deeper down.
class RefusalsTest < Minitest::Test
    Schedule = Thermidor::Schedule
    Syntax   = Schedule::Syntax

    TEXT_FORMS = %i[preset_ref preset band name program transition minute
                    days day_keys day_kind years duration dates time].freeze

    def test_a_text_form_takes_only_text
        TEXT_FORMS.product([nil, 5, :mon]).each do |form, value|
            assert_raises(Schedule::ParseError, "#{form}(#{value.inspect})") do
                Syntax.public_send(form, value)
            end
        end
    end

    def test_a_setting_not_known_is_refused
        error = assert_raises(Schedule::Error) do
            Schedule.configure(deadbnd: 2)
        end
        assert_match(/deadbnd/, error.message)
    end

    def test_a_transition_is_at_a_minute_of_the_day
        preset = Schedule::Preset::FROST
        [1440, -1, 3.5, nil, "06:30"].each do |minute|
            assert_raises(Schedule::Error, minute.inspect) do
                Schedule::Transition.new(minute:, preset:)
            end
        end
        assert_equal 1439, Schedule::Transition.new(minute: 1439, preset:)
                                               .minute
    end

    def test_weekdays_are_zero_to_six
        program = Schedule::Program.new(transitions: [])
        [7, -1, "mon", 1.0, nil].each do |key|
            assert_raises(ArgumentError, key.inspect) do
                Schedule::Timetable.new(days: { key => program })
            end
        end
        assert Schedule::Timetable.new(days: { 0 => program, 6 => program })
    end

    def test_a_calendar_entry_needs_a_priority_and_a_kind_of_day
        entry = Schedule::Layers::Calendar::Entry.new(
            id: 1, calendar: "fr", priority: 8, zone: nil, kind: "holiday",
            first: Date.new(2026, 12, 25), last: Date.new(2026, 12, 25),
            description: nil
        )
        assert_equal %w[sun holiday], [entry.with(kind: "sun").kind, entry.kind]
        assert_raises(ArgumentError) { entry.with(priority: nil) }
        ["sunday", "Holiday", "", nil, :holiday].each do |kind|
            assert_raises(ArgumentError, kind.inspect) { entry.with(kind:) }
        end
    end

    def test_a_stack_needs_a_layer
        assert_raises(ArgumentError) { Schedule::Stack.new([]) }
    end

    # Narrower than the deadband, backwards, or no numbers.
    def test_a_clamp_whose_limits_hold_no_band_is_refused
        [18.5..19.0, 30.0..5.0, "a".."z", nil].each do |limits|
            assert_raises(Schedule::Error, limits.inspect) do
                Schedule::Layers::Clamp.new(limits:)
            end
        end
    end
end
