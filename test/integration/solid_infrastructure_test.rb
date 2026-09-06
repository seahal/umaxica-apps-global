# typed: false
# frozen_string_literal: true

require "test_helper"

# Solid Cache is no longer part of the runtime architecture: application cache
# is Valkey-backed via CACHE_REDIS_URL, and PostgreSQL keeps only authoritative,
# durable and security-sensitive state. Solid Queue is deliberately unaffected
# and remains PostgreSQL-backed.
class SolidInfrastructureTest < ActiveSupport::TestCase
  test "test environment persists no application cache" do
    assert_instance_of ActiveSupport::Cache::NullStore, Rails.cache
  end

  test "solid cache is not loaded" do
    assert_not defined?(SolidCache), "Solid Cache must not be part of the runtime architecture"
  end

  test "no database connection is configured for a solid cache store" do
    configured = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).map(&:name)

    assert_not_includes configured, "cache"
    assert_not_includes configured, "cache_replica"
  end

  test "solid queue remains configured and postgresql-backed" do
    configured = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).map(&:name)

    assert_includes configured, "queue"
  end

  test "null cache reads are safe inside reading role" do
    ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
      assert_nil Rails.cache.read("reading_role_test_key")
    end
  end
end
