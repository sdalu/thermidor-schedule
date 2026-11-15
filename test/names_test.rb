# frozen_string_literal: true

require "test_helper"

# A name is ASCII and lowercase, a letter first, whether typed or
# given to a preset built in code: never a digit, a sign, a dash, a dot
# or an underscore first, no capital, no letter outside ASCII, no colon
# (:by and :at end a transition).
class NamesTest < Minitest::Test
    Schedule = Thermidor::Schedule
    Syntax   = Schedule::Syntax
    SETPOINT = Schedule::Setpoint.new(heat: 20)

    def test_a_letter_first_then_letters_digits_underscore_dash
        %w[eco ecran-2 etage_1 a1 sejour-ete].each do |name|
            assert_equal name, Syntax.name(name)
            assert_equal name, preset(name).name
        end
        assert_equal "eco", Syntax.preset("eco")
    end

    def test_no_digit_sign_dash_dot_underscore_first_capital_or_accent
        %w[20c 2nd-floor -eco +eco _eco .eco Eco eCo été 日本 on+time eco:by]
            .each do |name|
            assert_raises(Schedule::ParseError, name) { Syntax.name(name) }
            assert_raises(Schedule::Error, name) { preset(name) }
        end
    end

    # Bytes NAME cannot read are no name, not an encoding error.
    def test_text_of_another_encoding
        ["\xFFeco", "eco\xFF".b, "été".encode("ISO-8859-1"),
         "eco".encode("UTF-16LE")].each do |name|
            assert_raises(Schedule::ParseError, name.dump) { Syntax.name(name) }
            assert_raises(Schedule::Error, name.dump) { preset(name) }
        end
        assert_equal "eco", Syntax.name("eco".b)
    end

    private

    def preset(name) = Schedule::Preset.new(name:, setpoint: SETPOINT)
end
