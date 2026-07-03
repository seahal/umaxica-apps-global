# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseTrustedOriginsTest < ActiveSupport::TestCase
  test "production base trusted origins are explicit https origins without local fallbacks" do
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      app_origins = JitHostOriginEnv.trusted_origins(
        "base.umaxica.app",
        "auth.umaxica.app",
        "localhost",
        "https://127.0.0.1:3000",
      )
      org_origins = JitHostOriginEnv.trusted_origins("base.umaxica.org")
      com_origins = JitHostOriginEnv.trusted_origins("base.umaxica.com")

      assert_equal ["https://base.umaxica.app", "https://auth.umaxica.app"], app_origins
      assert_equal ["https://base.umaxica.org"], org_origins
      assert_equal ["https://base.umaxica.com"], com_origins
      assert_not_includes app_origins, "http://base.umaxica.app"
      assert_empty app_origins.grep(/localhost|127\.0\.0\.1/)
    end
  end

  test "production base trusted origins do not wildcard sibling or suffix-confused hosts" do
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      origins = JitHostOriginEnv.trusted_origins("base.umaxica.app")

      assert_includes origins, "https://base.umaxica.app"
      assert_not_includes origins, "https://evil.base.umaxica.app"
      assert_not_includes origins, "https://base.umaxica.app.evil.example"
      assert_not_includes origins, "https://umaxica.app"
    end
  end
end
