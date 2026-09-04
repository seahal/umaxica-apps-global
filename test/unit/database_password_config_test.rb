# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DatabasePasswordConfigTest < ActiveSupport::TestCase
  test "database password prefers POSTGRESQL_PASSWORD over credentials" do
    database_yml = Rails.root.join("config/database.yml").read

    assert_includes database_yml,
                    'ENV["POSTGRESQL_PASSWORD"].presence || Rails.application.credentials.dig(:DATABASE, :PASSWORD)'
    assert_includes database_yml, ".presence || Rails.application.credentials.dig(:DATABASE, :PASSWORD)"
  end

  test "development queue pools can serve every Solid Queue worker thread" do
    configurations = Rails.application.config.database_configuration.fetch("development")

    %w(queue queue_replica).each do |name|
      configuration = configurations.fetch(name)

      assert_operator configuration.fetch("pool"), :>=, 5, name
    end
  end

  test "production database connections require the shared Neon connection settings" do
    database_yml = Rails.root.join("config/database.yml").read

    assert_equal 21, database_yml.scan(/host: <%= production_value\.call\("NEON_PGHOST"\) %>/).size
    assert_equal 21, database_yml.scan(/username: <%= production_value\.call\("NEON_PGUSER"\) %>/).size
    assert_equal 21, database_yml.scan(/password: <%= production_value\.call\("NEON_PGPASSWORD"\) %>/).size
    assert_equal 20, database_yml.scan(/host: <%= production_value\.call\("NEON_REPLICA_PGHOST"\) %>/).size
    assert_equal 20, database_yml.scan(/username: <%= production_value\.call\("NEON_REPLICA_PGUSER"\) %>/).size
    assert_equal 20, database_yml.scan(/password: <%= production_value\.call\("NEON_REPLICA_PGPASSWORD"\) %>/).size
    assert_equal 20, database_yml.scan(/sslmode: <%= production_value\.call\("NEON_REPLICA_PGSSLMODE"\) %>/).size
    assert_equal 20,
                 database_yml.scan(/channel_binding: <%= production_value\.call\("NEON_REPLICA_PGCHANNELBINDING"\) %>/).size
    assert_includes database_yml, 'sslmode: <%= production_value.call("NEON_PGSSLMODE") %>'
    assert_includes database_yml, 'channel_binding: <%= production_value.call("NEON_PGCHANNELBINDING") %>'
    assert_includes database_yml, "Rails.env.production? ? ENV.fetch(name) : ENV[name]"
  end
end
