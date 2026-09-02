# typed: false
# frozen_string_literal: true

require "test_helper"

# Adding an address to an existing account carries a return target through the
# session and is gated by a stealth challenge. A failed challenge must stop the
# registration with an error on the form rather than sending a code, and a
# return target that no longer verifies must fall back to the default page
# rather than being followed as given.
class Base::Com::Identity::Emails::RegistrationsControllerGuardsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Base::Com::Identity::Emails::RegistrationsController
    attr_accessor :turnstile_result, :stored_pt, :signed_pt_result, :resolved_pt

    def cloudflare_turnstile_stealth_validation = turnstile_result

    def retrieve_pt(_key) = stored_pt

    def path_from_signed_pt(_encoded) = resolved_pt

    def signed_pt_token(_value) = signed_pt_result

    def t(key, **) = key.to_s

    def invoke(name, ...) = send(name, ...)

    def user_email = @user_email
  end

  setup do
    @harness = Harness.new
  end

  test "a failed stealth challenge stops the registration with an error on the form" do
    @harness.turnstile_result = { "success" => false }

    assert_not @harness.invoke(:initiate_visitor_email_verification!, "someone@example.com")
    assert_includes @harness.user_email.errors.full_messages.join(" "),
                    "sign.app.registration.email.create.turnstile_validation_failed"
  end

  test "a return target that no longer verifies falls back to the default page" do
    @harness.stored_pt = "encoded-pt"
    @harness.resolved_pt = nil

    assert_equal "/identity/emails", @harness.invoke(:email_registration_return_path, "/identity/emails")
  end

  test "a return target that verifies is used" do
    @harness.stored_pt = "encoded-pt"
    @harness.resolved_pt = "/identity/emails/new"

    assert_equal "/identity/emails/new", @harness.invoke(:email_registration_return_path, "/identity/emails")
  end

  test "a redirect parameter that cannot be re-signed is dropped rather than passed through" do
    @harness.signed_pt_result = nil
    redirect_params = { ri: "jp", pt: "untrusted" }

    @harness.invoke(:sanitize_redirect_params!, redirect_params)

    assert_equal({ ri: "jp" }, redirect_params)
  end

  test "a redirect parameter that re-signs is replaced by the signed form" do
    @harness.signed_pt_result = "signed-pt"
    redirect_params = { ri: "jp", pt: "untrusted" }

    @harness.invoke(:sanitize_redirect_params!, redirect_params)

    assert_equal({ ri: "jp", pt: "signed-pt" }, redirect_params)
  end
end
