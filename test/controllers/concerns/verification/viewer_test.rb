# typed: false
# frozen_string_literal: true

require "test_helper"

class Verification::ViewerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  Harness =
    Struct.new(:current_session_public_id_value, :cookies_hash, :scope) do
      include Verification::Base

      attr_accessor :request_fullpath, :params_hash

      def current_session_public_id = current_session_public_id_value

      def cookies = cookies_hash

      def params = params_hash || {}

      def request
        path = URI.parse(request_fullpath || "/").path
        Struct.new(:fullpath, :path, :get?, :head?, :format).new(
          request_fullpath || "/",
          path,
          true,
          false,
          Struct.new(:json?).new(false),
        )
      end

      def token_class = UserToken

      def verification_model = UserVerification

      def verification_token_foreign_key = :user_token_id

      def verification_scope = scope

      def actor_verification_path(**) = "/verification"

      def available_step_up_methods(*) = []

      def configured_step_up_methods(*) = [:email_otp]
    end

  test "includes verification base" do
    harness =
      Class.new do
        include Verification::Viewer
      end

    assert_includes harness.included_modules, Verification::Base
  end

  test "enforce_verification_if_required returns true when actor is not logged in" do
    harness =
      Class.new do
        include Verification::Viewer

        define_method(:logged_in?) do
          false
        end
      end

    assert harness.new.send(:enforce_verification_if_required)
  end

  test "verification_satisfied requires matching step up scope when verification cookie exists" do
    user = User.create!
    token = UserToken.create!(
      user: user,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      public_id: "v#{SecureRandom.hex(9)}",
      lapses_at: 1.day.from_now,
    )
    token.update!(created_at: 1.hour.ago, last_step_up_at: 10.minutes.ago, last_step_up_scope: "withdrawal")
    verification, raw_token = UserVerification.issue_for_token!(token: token)

    mismatch = Harness.new(token.public_id, { UserVerification.cookie_name => raw_token }, "configuration_email")
    match = Harness.new(token.public_id, { UserVerification.cookie_name => raw_token }, "withdrawal")

    assert_not_predicate mismatch, :verification_satisfied?
    assert_predicate match, :verification_satisfied?
    assert_predicate verification.reload, :active?
  end

  test "verification_satisfied accepts test verification cookies without a database lookup" do
    user = User.create!
    token = UserToken.create!(
      user: user,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      public_id: "t#{SecureRandom.hex(6)}",
      lapses_at: 1.day.from_now,
    )
    token.update!(created_at: 1.hour.ago)

    harness = Harness.new(
      token.public_id,
      { UserVerification.cookie_name => "test_verified:#{token.public_id}" },
      "configuration_email",
    )

    assert_predicate harness, :verification_satisfied?
  end

  test "encoded step up return_to unwraps nested verification return_to" do
    target = "/configuration/challenge?ri=jp"
    nested = "/verification?ri=jp&rt=#{Base64.urlsafe_encode64(target)}&scope=configuration_mfa"
    harness = Harness.new(nil, {}, "configuration_mfa")
    harness.request_fullpath = nested

    decoded = Base64.urlsafe_decode64(harness.send(:encoded_step_up_rt))

    assert_equal target, decoded
  end

  test "encoded step up return_to preserves existing rt instead of current verification url" do
    target = "/configuration/challenge?ri=jp"
    nested = "/verification?ri=jp&rt=#{Base64.urlsafe_encode64(target)}&scope=configuration_mfa"
    harness = Harness.new(nil, {}, "configuration_mfa")
    harness.request_fullpath = nested
    harness.params_hash = { rt: Base64.urlsafe_encode64(target), scope: "configuration_mfa", ri: "jp" }

    decoded = Base64.urlsafe_decode64(harness.send(:encoded_step_up_rt))

    assert_equal target, decoded
  end

  test "enforce step up prereqs does not redirect from verification entry to itself" do
    harness = Harness.new(nil, {}, "configuration_email")
    harness.request_fullpath = "/verification?ri=jp&rt=#{Base64.urlsafe_encode64("/configuration/emails?ri=jp")}&scope=configuration_email"

    assert harness.send(:enforce_step_up_prereqs!)
  end
end
