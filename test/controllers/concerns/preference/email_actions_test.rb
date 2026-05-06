# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceEmailActionsHarness < ApplicationController
  include Preference::EmailActions

  attr_accessor :params_hash, :render_args, :redirected_to, :found_record

  def params = ActionController::Parameters.new(params_hash || {})

  def audience_name = "app"

  def preference_mailer_class = Email::App::PreferenceMailer

  def find_email_record_by_address(_) = found_record

  def preference_email_new_path = "/preference/emails/new"

  def preference_email_edit_url(token) = "/preference/emails/#{token}/edit"

  def render(*args, **kwargs) = self.render_args = [args, kwargs]

  def redirect_to(path) = self.redirected_to = path

  def t(key) = key
end

class Preference::EmailActionsTest < ActiveSupport::TestCase
  setup do
    @controller = PreferenceEmailActionsHarness.new
    @controller.request = ActionDispatch::TestRequest.create
    @controller.response = ActionDispatch::TestResponse.new
  end

  test "email params keys and record class helpers" do
    @controller.params_hash = { preference_email: { email: " User@Example.COM " } }

    assert_equal "User@Example.COM", @controller.send(:email_param)
    assert_equal UserEmail, @controller.send(:email_record_class, "UserEmail")
    assert_equal CustomerEmail, @controller.send(:email_record_class, "CustomerEmail")
    assert_raises(ArgumentError) { @controller.send(:email_record_class, "BadEmail") }
    assert_equal "base.app.preference.emails.new.failure", @controller.send(:preference_email_failure_key, :new)
    assert_equal "base.app.preference.emails.edit.submit", @controller.send(:preference_email_success_key, :edit)
  end

  test "create handles turnstile and email validation failures" do
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => false }
    @controller.params_hash = { preference_email: { email: "bad" } }

    @controller.create

    assert_equal [[:new], { status: :unprocessable_content }], @controller.render_args

    CloudflareTurnstile.test_validation_response = { "success" => true }
    @controller.render_args = nil
    @controller.create

    assert_equal [[:new], { status: :unprocessable_content }], @controller.render_args
  ensure
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "edit update and unsubscribe reject invalid tokens" do
    @controller.params_hash = { token: "bad" }

    @controller.edit

    assert_equal "/preference/emails/new", @controller.redirected_to

    @controller.redirected_to = nil
    @controller.update

    assert_equal "/preference/emails/new", @controller.redirected_to

    @controller.redirected_to = nil
    @controller.unsubscribe

    assert_equal "/preference/emails/new", @controller.redirected_to
  end
end
