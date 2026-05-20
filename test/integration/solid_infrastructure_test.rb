# typed: false
# frozen_string_literal: true

require "test_helper"

class SolidInfrastructureTest < ActiveSupport::TestCase
  test "test environment uses null cache store with solid cache replica configuration" do
    assert_instance_of ActiveSupport::Cache::NullStore, Rails.cache
    assert_equal(
      { shards: { cache: { writing: :cache, reading: :cache_replica } } },
      SolidCache.configuration.connects_to,
    )
  end

  test "null cache reads are safe inside reading role" do
    ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
      assert_nil Rails.cache.read("reading_role_test_key")
    end
  end
end
