# typed: false
# frozen_string_literal: true

require "test_helper"

class RateLimitProfilesTest < ActiveSupport::TestCase
  test "email submission profile is shared and relaxed enough for sign up" do
    profile = RateLimitProfiles.email_address_submit

    assert_equal 30, profile.to
    assert_equal 10.minutes, profile.within
    assert_equal 600, profile.retry_after
  end

  test "interactive post and credential verify profiles stay distinct" do
    post_profile = RateLimitProfiles.interactive_post_ip
    verify_subject = RateLimitProfiles.credential_verify_subject
    verify_ip = RateLimitProfiles.credential_verify_ip

    assert_equal 30, post_profile.to
    assert_equal 10, verify_subject.to
    assert_equal 30, verify_ip.to
    assert_equal 1.minute, verify_ip.within
  end

  test "oauth authorize is relaxed in test and development" do
    profile_set = RateLimitProfiles.oauth_authorize

    assert_equal 300, profile_set.ip_surface.to
    assert_equal 120, profile_set.browser_client.to
    assert_equal 1000, profile_set.client_redirect_host.to
    assert_equal 10.minutes, profile_set.client_redirect_host.within
  end

  test "oauth authorize is tighter in production" do
    Rails.env
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      profile_set = RateLimitProfiles.oauth_authorize

      assert_equal 120, profile_set.ip_surface.to
      assert_equal 60, profile_set.browser_client.to
      assert_equal 600, profile_set.client_redirect_host.to
      assert_equal 10.minutes, profile_set.client_redirect_host.within
    end
  end

  test "page view get profile has expected limits" do
    profile = RateLimitProfiles.page_view_get

    assert_equal 120, profile.to
    assert_equal 1.minute, profile.within
    assert_equal 60, profile.retry_after
  end

  test "token endpoint profile has expected limits" do
    profile = RateLimitProfiles.token_endpoint

    assert_equal 30, profile.to
    assert_equal 1.minute, profile.within
    assert_equal 60, profile.retry_after
  end

  test "email address submit is tighter in production" do
    Rails.env
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      profile = RateLimitProfiles.email_address_submit

      assert_equal 10, profile.to
      assert_equal 10.minutes, profile.within
      assert_equal 600, profile.retry_after
    end
  end
end
