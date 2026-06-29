# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SolidInfrastructureTest < ActiveSupport::TestCase
  test "test environment uses null cache store and leaves solid cache disconnected" do
    assert_instance_of ActiveSupport::Cache::NullStore, Rails.cache
    assert_nil SolidCache.configuration.connects_to
  end

  test "null cache reads are safe inside reading role" do
    ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
      assert_nil Rails.cache.read("reading_role_test_key")
    end
  end
end
