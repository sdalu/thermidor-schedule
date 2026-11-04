# frozen_string_literal: true

require "date"

module Thermidor
    module Schedule
        # Public holidays by region, to fill a calendar with. Each region
        # lists its holidays as a name and either a fixed [month, day] or a
        # day offset from Easter Sunday.
        module Holidays
            FRANCE = {
                "Jour de l’an" => [1, 1], "Lundi de Pâques" => 1,
                "Fête du Travail" => [5, 1], "Victoire 1945" => [5, 8],
                "Ascension" => 39, "Lundi de Pentecôte" => 50,
                "Fête nationale" => [7, 14], "Assomption" => [8, 15],
                "Toussaint" => [11, 1], "Armistice 1918" => [11, 11],
                "Noël" => [12, 25]
            }.freeze

            REGIONS = {
                "fr" => FRANCE,
                "fr-alsace-moselle" => FRANCE.merge(
                    "Vendredi saint" => -2, "Saint-Étienne" => [12, 26]
                )
            }.freeze

            module_function

            # [[Date, name], ...] for `year`, in date order.
            def for(region, year)
                rules = REGIONS.fetch(region) do
                    raise Error, "unknown region #{region} " \
                                 "(#{REGIONS.keys.join(", ")})"
                end
                easter = easter(year)
                rules.map { |name, rule| [date(year, rule, easter), name] }
                     .sort
            end

            # A fixed [month, day], or days from Easter Sunday.
            def date(year, rule, easter)
                return easter + rule if rule.is_a?(Integer)
                Date.new(year, *rule)
            end

            # Easter Sunday in the Gregorian calendar: the anonymous
            # algorithm of Meeus, Jones and Butcher.
            def easter(year)
                golden = year % 19
                moon   = full_moon(year, golden)
                sunday = to_sunday(year, moon)
                shift  = (golden + (11 * moon) + (22 * sunday)) / 451
                month, day = (moon + sunday - (7 * shift) + 114).divmod(31)
                Date.new(year, month, day + 1)
            end

            # Days from 21 March to the paschal full moon.
            def full_moon(year, golden)
                century = year / 100
                skipped = (century - ((century + 8) / 25) + 1) / 3
                ((19 * golden) + century - (century / 4) - skipped + 15) % 30
            end

            # Days from that full moon to the Sunday after it.
            def to_sunday(year, moon)
                century, rest = year.divmod(100)
                (32 + (2 * (century % 4)) + (2 * (rest / 4)) - moon -
                 (rest % 4)) % 7
            end
        end
    end
end
