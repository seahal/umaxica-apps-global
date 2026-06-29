# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class AppConfigRuntimeModulesTest < ActiveSupport::TestCase
  test "app config does not contain runtime Ruby modules" do
    runtime_files =
      Rails.root.glob("app/config/**/*.rb").map do |path|
        Pathname(path).relative_path_from(Rails.root).to_s
      end

    assert_empty runtime_files, "move runtime Ruby modules out of app/config: #{runtime_files.join(", ")}"
  end
end
