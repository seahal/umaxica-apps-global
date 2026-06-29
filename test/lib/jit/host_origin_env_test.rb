# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_host_origin_env"

module Jit
  class HostOriginEnvTest < ActiveSupport::TestCase
    test "trusted_origins expands hostnames to both http and https outside production" do
      env = ActiveSupport::EnvironmentInquirer.new("test")

      Rails.stub(:env, env) do
        origins = JitHostOriginEnv.trusted_origins("id.app.localhost")

        assert_includes origins, "http://id.app.localhost"
        assert_includes origins, "https://id.app.localhost"
      end
    end

    test "trusted_origins keeps explicit origins as-is" do
      env = ActiveSupport::EnvironmentInquirer.new("production")

      Rails.stub(:env, env) do
        origins = JitHostOriginEnv.trusted_origins("https://id.app.example.com")

        assert_equal ["https://id.app.example.com"], origins
      end
    end

    test "trusted_origins removes blanks and deduplicates origins" do
      env = ActiveSupport::EnvironmentInquirer.new("development")

      Rails.stub(:env, env) do
        origins = JitHostOriginEnv.trusted_origins(nil, "", "id.app.localhost", "id.app.localhost")

        assert_equal ["http://id.app.localhost", "https://id.app.localhost"], origins
      end
    end

    test "origins_for uses https only in production for bare hosts" do
      env = ActiveSupport::EnvironmentInquirer.new("production")

      Rails.stub(:env, env) do
        assert_equal ["https://id.app.localhost"], JitHostOriginEnv.origins_for("id.app.localhost")
      end
    end
  end
end
