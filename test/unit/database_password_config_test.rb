# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class DatabasePasswordConfigTest < ActiveSupport::TestCase
  test "database password prefers POSTGRESQL_PASSWORD over credentials" do
    database_yml = Rails.root.join("config/database.yml").read

    assert_includes database_yml, 'password: <%= ENV["POSTGRESQL_PASSWORD"]'
    assert_includes database_yml, ".presence || Rails.application.credentials.dig(:DATABASE, :PASSWORD) %>"
  end
end
