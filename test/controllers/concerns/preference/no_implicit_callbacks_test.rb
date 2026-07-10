# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceNoImplicitCallbacksTest < ActiveSupport::TestCase
  CALLBACK_REGISTRATION_METHODS = %w(
    before_action after_action around_action
    prepend_before_action prepend_after_action prepend_around_action
    skip_before_action skip_after_action skip_around_action
  ).freeze

  test "preference concerns do not register callbacks through included blocks" do
    files = Rails.root.glob("app/controllers/concerns/preference_*.rb")
    offenders =
      files.filter_map do |file|
        path = Pathname(file).relative_path_from(Rails.root).to_s
        content = File.read(file)
        next unless content.match?(/included\s+do/)

        included_block = content[/included\s+do(.*?)^\s*end/m, 1].to_s
        path if CALLBACK_REGISTRATION_METHODS.any? { |method| included_block.match?(/\b#{method}\b/) }
      end

    assert_empty offenders
  end
end
