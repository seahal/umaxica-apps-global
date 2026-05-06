# typed: false
# frozen_string_literal: true

require "test_helper"

class HostOriginEnvTest < ActiveSupport::TestCase
  test "trusted_origins expands hostnames to both http and https outside production" do
    env = ActiveSupport::EnvironmentInquirer.new("test")

    Rails.stub(:env, env) do
      origins = HostOriginEnv.trusted_origins("id.app.localhost")

      assert_includes origins, "http://id.app.localhost"
      assert_includes origins, "https://id.app.localhost"
    end
  end

  test "trusted_origins keeps explicit origins as-is" do
    env = ActiveSupport::EnvironmentInquirer.new("production")

    Rails.stub(:env, env) do
      origins = HostOriginEnv.trusted_origins("https://id.app.example.com")

      assert_equal ["https://id.app.example.com"], origins
    end
  end
end
