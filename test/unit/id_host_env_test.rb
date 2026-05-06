# typed: false
# frozen_string_literal: true

require "test_helper"

class IdHostEnvTest < ActiveSupport::TestCase
  test "service_url reads ID_SERVICE_URL" do
    with_env("ID_SERVICE_URL" => "id.app.example.test") do
      assert_equal "id.app.example.test", ENV["ID_SERVICE_URL"]
      assert_equal "id.app.example.test", IdHostEnv.service_url
    end
  end

  test "staff_url reads ID_STAFF_URL" do
    with_env("ID_STAFF_URL" => "id.org.example.test") do
      assert_equal "id.org.example.test", IdHostEnv.staff_url
    end
  end

  test "validate! raises when service host is missing" do
    with_env(
      "ID_SERVICE_URL" => nil, "ID_CORPORATE_URL" => "id.com.example.test",
      "ID_STAFF_URL" => "id.org.example.test",
    ) do
      error = assert_raises(IdHostEnv::MissingHostError) { IdHostEnv.validate! }

      assert_includes error.message, "ID_SERVICE_URL"
    end
  end

  test "validate! raises when staff host is missing" do
    with_env(
      "ID_SERVICE_URL" => "id.app.example.test", "ID_CORPORATE_URL" => "id.com.example.test",
      "ID_STAFF_URL" => nil,
    ) do
      error = assert_raises(IdHostEnv::MissingHostError) { IdHostEnv.validate! }

      assert_includes error.message, "ID_STAFF_URL"
    end
  end

  test "validate! passes when all hosts are present" do
    with_env(
      "ID_SERVICE_URL" => "id.app.example.test", "ID_CORPORATE_URL" => "id.com.example.test",
      "ID_STAFF_URL" => "id.org.example.test",
    ) do
      assert_nil IdHostEnv.validate!
    end
  end

  private

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }

    vars.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
