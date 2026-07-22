# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DatabasePasswordConfigTest < ActiveSupport::TestCase
  test "database password prefers POSTGRESQL_PASSWORD over credentials" do
    database_yml = Rails.root.join("config/database.yml").read

    assert_includes database_yml, 'password: <%= ENV["POSTGRESQL_PASSWORD"]'
    assert_includes database_yml, ".presence || Rails.application.credentials.dig(:DATABASE, :PASSWORD) %>"
  end

  test "development queue pools can serve every Solid Queue worker thread" do
    configurations = ActiveRecord::Base.configurations

    %w[queue queue_replica].each do |name|
      configuration = configurations.configs_for(env_name: "development", name: name)

      assert_operator configuration.configuration_hash.fetch(:pool), :>=, 5, name
    end
  end
end
