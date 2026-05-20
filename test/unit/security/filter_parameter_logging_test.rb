# typed: false
# frozen_string_literal: true

require "test_helper"

class FilterParameterLoggingTest < ActiveSupport::TestCase
  test "filters birthdate from logged parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter("birthdate" => "2000-02-03")

    assert_equal "[FILTERED]", filtered.fetch("birthdate")
  end
end
