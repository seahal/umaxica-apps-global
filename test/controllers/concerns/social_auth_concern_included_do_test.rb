# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthConcernIncludedDoTest < ActiveSupport::TestCase
  test "handle_social_auth_error method exists (private)" do
    assert_includes SocialAuthConcern.private_instance_methods(false), :handle_social_auth_error
  end

  test "handle_record_not_unique method exists (private)" do
    assert_includes SocialAuthConcern.private_instance_methods(false), :handle_record_not_unique
  end

  test "VALID_INTENTS constant is defined" do
    assert_equal %w(login link reauth), SocialAuthConcern::VALID_INTENTS
  end

  test "prepare_social_auth_intent! method exists (private)" do
    assert_includes SocialAuthConcern.private_instance_methods(false), :prepare_social_auth_intent!
  end
end
