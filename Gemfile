# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
    gem "minitest", "~> 5.25"
    gem "rake", "~> 13.2"
    gem "rubocop", "~> 1.90"
    # A reference RFC 5545 implementation, which Recurrence is compared
    # with (test/recurrence_reference_test.rb).
    gem "rrule", "~> 0.8"
end

group :development do
    # A sampling profiler, for what a resolution or a walk ahead costs;
    # the suite does not load it.
    gem "stackprof", "~> 0.2.28"
end
