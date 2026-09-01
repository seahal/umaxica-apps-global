# typed: false
# frozen_string_literal: true

require "test_helper"

# Linking a social provider from settings is a privileged change to how an
# account can be signed into, so it has to be recently step-up verified. The
# guard lets four different situations straight through, and each pass-through is
# a case where the link proceeds without a step-up -- correct for three of them
# and the whole point of the guard for the fourth.
class SocialLinkStepUpAndAttemptsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # The concern declares a rescue_from when included, so the harness has to be a
  # controller. ApplicationController would drag in the surface stack this is
  # deliberately outside of.
  class EntryHarness < ActionController::Base # rubocop:disable Rails/ApplicationController
    include ::AppSocialCeremonyEntry

    attr_accessor :params, :signed_in, :resource, :step_up_ok, :redirects

    def initialize(**attributes)
      super()
      @params = ActionController::Parameters.new(ri: "jp")
      @redirects = []
      attributes.each { |name, value| public_send(:"#{name}=", value) }
    end

    def invoke(name, ...) = send(name, ...)

    def logged_in? = signed_in

    def current_resource = resource

    def step_up_satisfied?(scope:) = step_up_ok && scope == ::AppSocialCeremonyEntry::SOCIAL_LINK_SCOPE

    def redirect_to(*args, **kwargs) = redirects << [args, kwargs]

    def actor_verification_path(**attrs) = "/verification?#{attrs.compact.to_query}"

    def encoded_relative_pt(path) = Base64.urlsafe_encode64(path, padding: false)

    def auth_app_settings_apple_path(**attrs) = "/settings/apple?#{attrs.compact.to_query}"

    def auth_app_settings_google_path(**attrs) = "/settings/google?#{attrs.compact.to_query}"
  end

  def link_params(provider: "google")
    ActionController::Parameters.new(intent: "link", provider: provider, ri: "jp")
  end

  test "anything that is not a link intent passes straight through" do
    harness = EntryHarness.new
    harness.params = ActionController::Parameters.new(intent: "login", provider: "google")

    assert harness.invoke(:require_social_link_step_up!)
    assert_empty harness.redirects
  end

  test "a provider the surface does not offer passes through rather than demanding a step-up" do
    harness = EntryHarness.new
    harness.params = link_params(provider: "line")

    assert harness.invoke(:require_social_link_step_up!)
    assert_empty harness.redirects
  end

  test "an anonymous caller passes through because there is no account to link to" do
    signed_out = EntryHarness.new(params: link_params)

    assert signed_out.invoke(:require_social_link_step_up!)

    no_resource = EntryHarness.new(params: link_params, signed_in: true)

    assert no_resource.invoke(:require_social_link_step_up!)
    assert_empty no_resource.redirects
  end

  test "a signed-in caller with a recent step-up proceeds, and one without is sent to verify" do
    verified = EntryHarness.new(params: link_params, signed_in: true, resource: :client, step_up_ok: true)

    assert verified.invoke(:require_social_link_step_up!)
    assert_empty verified.redirects

    unverified = EntryHarness.new(params: link_params, signed_in: true, resource: :client)

    assert_not unverified.invoke(:require_social_link_step_up!)
    assert_equal 1, unverified.redirects.size
    target, options = unverified.redirects.first

    assert_equal :see_other, options.fetch(:status)
    assert_includes target.first, "scope=#{::AppSocialCeremonyEntry::SOCIAL_LINK_SCOPE}"
    assert_includes target.first, Base64.urlsafe_encode64("/settings/google?ri=jp", padding: false)
  end

  test "the step-up returns to the settings page of the provider being linked" do
    harness = EntryHarness.new

    assert_equal "/settings/apple?ri=jp", harness.invoke(:social_link_settings_path, "apple")
    assert_equal "/settings/google?ri=jp", harness.invoke(:social_link_settings_path, "google")
  end

  test "an unparsable referer is read as a sign-in entry rather than raising" do
    harness = EntryHarness.new
    request = Struct.new(:parameters, :referer).new({}, "http://[oops")
    harness.define_singleton_method(:request) { request }

    assert_equal "sign_in", harness.invoke(:social_auth_entry)
  end
end
