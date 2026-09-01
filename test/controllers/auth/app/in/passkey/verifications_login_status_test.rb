# typed: false
# frozen_string_literal: true

require "test_helper"

# A passkey sign-in that commits but does not complete must tell the browser
# what is still required. The two statuses that carry their own response --
# a second factor still needed, and a session-limit refusal -- are answered
# here; anything else is left to the shared handling, which is what the boolean
# return communicates.
class Auth::App::Sign::In::Passkey::VerificationsLoginStatusTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::App::Sign::In::Passkey::VerificationsController
    attr_reader :rendered, :hard_reject

    def render(*args, **kwargs)
      @rendered = [args, kwargs]
    end

    def render_session_limit_hard_reject(message: nil, http_status: nil)
      @hard_reject = [message, http_status]
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "a result that still needs a second factor is answered with the next destination" do
    handled = @harness.invoke(
      :handle_domain_specific_login_status,
      { status: :mfa_required, redirect_path: "/sign/in/challenge" },
    )

    assert handled
    assert_equal(
      [[], { json: { status: "mfa_required", redirect_url: "/sign/in/challenge" }, status: :ok }],
      @harness.rendered,
    )
  end

  test "a session-limit refusal is answered with the status and message it carries" do
    handled = @harness.invoke(
      :handle_domain_specific_login_status,
      { status: :session_limit_hard_reject, message: "too many", http_status: :forbidden },
    )

    assert handled
    assert_equal ["too many", :forbidden], @harness.hard_reject
  end

  test "any other status is left to the shared handling" do
    assert_not @harness.invoke(:handle_domain_specific_login_status, { status: :success })
  end

  test "an account that is no longer active is not offered as a passkey actor" do
    active = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    withdrawn = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    withdrawn.update_columns(withdrawn_at: 1.day.ago)

    @harness.define_singleton_method(:find_user_by_identifier) { |identifier| identifier }

    assert_equal active, @harness.invoke(:find_active_passkey_actor, active)
    assert_nil @harness.invoke(:find_active_passkey_actor, withdrawn.reload)
    assert_nil @harness.invoke(:find_active_passkey_actor, nil)
  end
end
