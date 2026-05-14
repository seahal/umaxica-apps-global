# typed: false
# frozen_string_literal: true

require "test_helper"

class SolidInfrastructureTest < ActiveSupport::TestCase
  test "test environment uses memory cache store" do
    assert_instance_of ActiveSupport::Cache::MemoryStore, Rails.cache

    Rails.cache.write("test_key", "test_value")

    assert_equal "test_value", Rails.cache.read("test_key")
  end
end
