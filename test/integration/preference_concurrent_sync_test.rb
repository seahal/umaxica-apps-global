# typed: false
# frozen_string_literal: true

require "test_helper"

# Minitest cannot exercise true thread-level concurrency for a login-sync
# race, so this pins the invariants that make a race safe instead: unique
# jti/public_id at the DB layer, and no duplicate canonical preference row
# appearing after a burst of sequential writes that stand in for interleaved
# requests from the same client.
class PreferenceConcurrentSyncTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  COOKIE_NAME = -> { PreferenceCookieName.refresh(production: false, surface: :app) }

  test "jti stays unique across a burst of sequential writes against the same cookie" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    5.times do |i|
      patch base_app_preference_theme_url(ri: "jp"),
            params: { preference_theme: { option_id: i.even? ? "dr" : "sy" } }

      assert_response :redirect
    end

    jtis = AppPreference.where.not(jti: nil).pluck(:jti)

    assert_equal jtis.uniq.size, jtis.size, "jti must remain unique after a burst of sequential writes"

    public_ids = AppPreference.pluck(:public_id)

    assert_equal public_ids.uniq.size, public_ids.size, "public_id must remain unique after a burst of writes"
  end

  test "exactly one non-deleted preference backs the cookie after a burst of sequential writes" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    3.times do
      patch base_app_preference_theme_url(ri: "jp"),
            params: { preference_theme: { option_id: "dr" } }

      assert_response :redirect
    end

    token = cookies[COOKIE_NAME.call]

    assert_not_nil token

    verifier = token.include?(".") ? token.split(".", 2).last : token
    digest = SHA3::Digest::SHA3_384.digest(verifier)

    matches = AppPreference.where(token_digest: digest).where.not(status_id: AppPreferenceStatus::DELETED)

    assert_equal 1, matches.count,
                 "exactly one non-deleted preference should back the cookie after repeated writes"
  end
end
