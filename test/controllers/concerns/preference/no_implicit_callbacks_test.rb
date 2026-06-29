# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceNoImplicitCallbacksTest < ActiveSupport::TestCase
  test "preference concerns do not register callbacks through included blocks" do
    files = Rails.root.glob("app/controllers/concerns/preference_*.rb")
    offenders =
      files.filter_map do |file|
        path = Pathname(file).relative_path_from(Rails.root).to_s
        path if File.read(file).match?(/included\s+do/)
      end

    assert_empty offenders
  end
end
