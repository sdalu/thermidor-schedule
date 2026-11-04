# frozen_string_literal: true

require "test_helper"

class HolidaysTest < Minitest::Test
    Holidays = Thermidor::Schedule::Holidays

    # Published dates of Easter Sunday.
    EASTERS = { 2000 => [4, 23], 2008 => [3, 23], 2011 => [4, 24],
                2019 => [4, 21], 2024 => [3, 31], 2027 => [3, 28],
                2038 => [4, 25], 2285 => [3, 22] }.freeze

    def test_easter
        EASTERS.each do |year, (month, day)|
            assert_equal Date.new(year, month, day), Holidays.easter(year)
        end
    end

    def test_france_follows_easter
        days = Holidays.for("fr", 2027).to_h
        assert_equal 11, days.size
        names = [[3, 29], [5, 6], [5, 17]].map { days[Date.new(2027, *it)] }
        assert_equal ["Lundi de Pâques", "Ascension", "Lundi de Pentecôte"],
                     names
        assert_equal days.keys.sort, days.keys
    end

    def test_alsace_moselle_adds_two
        days = Holidays.for("fr-alsace-moselle", 2027).to_h
        assert_equal 13, days.size
        assert_equal "Vendredi saint", days[Date.new(2027, 3, 26)]
        assert_equal "Saint-Étienne", days[Date.new(2027, 12, 26)]
    end

    def test_unknown_region
        assert_raises(Thermidor::Schedule::Error) do
            Holidays.for("xx", 2027)
        end
    end
end
