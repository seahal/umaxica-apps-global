# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JitHostOriginEnvTest < ActiveSupport::TestCase
  test "trusted_origins flattens and deduplicates origins" do
    origins = JitHostOriginEnv.trusted_origins(%w(app.localhost com.localhost))

    assert_includes origins, "http://app.localhost"
    assert_includes origins, "https://app.localhost"
    assert_includes origins, "http://com.localhost"
    assert_equal origins.uniq, origins
  end

  test "origins_for returns an empty array for blank hosts" do
    assert_empty JitHostOriginEnv.origins_for(nil)
    assert_empty JitHostOriginEnv.origins_for("   ")
  end

  test "origins_for preserves an explicit scheme" do
    assert_equal ["https://app.localhost"], JitHostOriginEnv.origins_for("https://app.localhost")
  end

  test "origins_for returns only https in non-local environments" do
    Rails.env.stub(:local?, false) do
      assert_empty JitHostOriginEnv.origins_for("app.localhost")
      assert_equal ["https://app.example.com"], JitHostOriginEnv.origins_for("app.example.com")
    end
  end

  test "origins_for returns both http and https in local environments" do
    Rails.env.stub(:local?, true) do
      assert_equal ["http://app.localhost", "https://app.localhost"], JitHostOriginEnv.origins_for("app.localhost")
    end
  end
end
