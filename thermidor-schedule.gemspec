# frozen_string_literal: true

require_relative "lib/thermidor/schedule/version"

Gem::Specification.new do |s|
    s.name        = "thermidor-schedule"
    s.version     = Thermidor::Schedule::VERSION
    s.authors     = ["Stéphane D'Alu"]
    s.email       = ["sdalu@sdalu.com"]

    s.summary     = "Comfort bands over time: timetables, calendars and " \
                    "overrides, layered"
    s.description = "What each zone of a house should hold, heat below " \
                    "one setpoint and cool above another, over time. " \
                    "Decisions come from a stack of layers (a weekly " \
                    "timetable, a calendar with recurring entries and " \
                    "public holidays, away, manual, boost, open window, " \
                    "a clamp), each passing the decision below through " \
                    "or replacing it, so nothing has to remember what " \
                    "to restore. Standard library only."
    s.homepage    = "https://github.com/sdalu/thermidor-schedule"
    s.license     = "MIT"

    s.required_ruby_version = ">= 3.4"

    s.metadata = {
        "homepage_uri" => s.homepage,
        "rubygems_mfa_required" => "true"
    }

    s.files = Dir.chdir(__dir__) do
        Dir["{lib}/**/*", "LICENSE.txt", "README.md"]
            .reject { |f| File.directory?(f) }
    end

    s.require_paths = ["lib"]
end
