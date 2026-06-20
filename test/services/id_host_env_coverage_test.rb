# typed: false
# frozen_string_literal: true

require "test_helper"

class IdHostEnvCoverageTest < ActiveSupport::TestCase
  test "JitIdHostEnv coverage" do
    with_env(
      "ID_SERVICE_URL" => "id.app.example.test", "SIGN_CORPORATE_URL" => "id.com.example.test",
      "ID_STAFF_URL" => "id.org.example.test",
    ) do
      assert_equal "id.app.example.test", JitIdHostEnv.service_url
      assert_equal "id.org.example.test", JitIdHostEnv.staff_url
      assert_nil JitIdHostEnv.validate!
    end

    with_env("ID_SERVICE_URL" => nil) do
      error = assert_raises(JitIdHostEnv::MissingHostError) { JitIdHostEnv.validate! }
      assert_includes error.message, "ID_SERVICE_URL"
    end
  end

  private

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
