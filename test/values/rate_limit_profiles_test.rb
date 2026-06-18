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
end
