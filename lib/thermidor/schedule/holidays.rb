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

            @regions = REGIONS.dup

            module_function

            # The regions known: the built-in ones and those registered.
            def regions = @regions.keys

            # Adds a region, its holidays given as REGIONS gives them. A
            # region already known, or a rule that is no date, is refused.
            def register(region, rules)
                raise Error, "region #{region} is known" if
                    @regions.key?(region)
                raise Error, "region #{region}: no holiday" unless
                    rules.is_a?(Hash) && rules.any?
                rules.each { |name, rule| check(region, name, rule) }
                @regions[region] = rules.to_h do |name, rule|
                    [name.dup.freeze, rule.dup.freeze]
                end.freeze
            end

            # Days from Easter that stay within its year, whatever its date
            # (22 March to 25 April), or a [month, day] of every year.
            EASTER_OFFSETS = (-80..249)

            def check(region, name, rule)
                return if date?(rule)
                raise Error, "region #{region}: #{name} #{rule.inspect} " \
                             "is no date"
            end

            def date?(rule)
                return EASTER_OFFSETS.cover?(rule) if rule.is_a?(Integer)
                rule.is_a?(Array) && rule.size == 2 &&
                    rule.all?(Integer) && Date.valid_date?(2001, *rule)
            end

            # [[Date, name], ...] for `year`, in date order.
            def for(region, year)
                rules = @regions.fetch(region) do
                    raise Error, "unknown region #{region} " \
                                 "(#{regions.join(", ")})"
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
