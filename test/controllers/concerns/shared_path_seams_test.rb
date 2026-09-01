# typed: false
# frozen_string_literal: true

require "test_helper"

# Shared flows ask the including surface for a path, and each of these answers
# from the surface's own route helpers or falls back to a documented default.
# Getting one wrong sends a signed-in client, a sign-up applicant or a
# withdrawal ceremony onto a surface that is not theirs.
class SharedPathSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(concern, &definition)
    Class.new(ActionController::Base) do
      include concern

      attr_accessor :params_hash

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new.tap do |h|
      h.params_hash = { ri: "jp" }
      h.request = ActionDispatch::TestRequest.create
    end
  end

  test "a canonical dbsc url drops the query so the same session is never registered twice" do
    subject = harness(DbscCanonicalUrl)

    assert_equal "", subject.invoke(:dbsc_canonical_url, "")
    assert_equal "https://auth.example/edge/v0/dbsc", subject.invoke(
      :dbsc_canonical_url, "https://auth.example/edge/v0/dbsc?session=1",
    )
  end

  test "the withdrawal ceremony entry prefers the session entry point when the surface has one" do
    with_session = harness(WithdrawalCeremonyAuthentication) do
      def withdrawal_session_new_path = "/identity/withdrawal/session/new"
    end
    without_session = harness(WithdrawalCeremonyAuthentication) do
      def withdrawal_new_path = "/identity/withdrawal/new"
    end

    assert_equal "/identity/withdrawal/session/new", with_session.invoke(:withdrawal_ceremony_entry_path)
    assert_equal "/identity/withdrawal/new", without_session.invoke(:withdrawal_ceremony_entry_path)
  end

  # The staff surface has no sign-up of its own, so its fallback is the site root.
  { app: "/sign/in", com: "/sign/in", org: "/" }.each do |surface, expected|
    test "the #{surface} sign-up flow falls back to its own sign-in entry point" do
      subject = harness(SignUpSequenceControllerSupport) do
        define_method(:sign_up_surface) { surface }
      end

      assert_includes subject.invoke(:sign_up_default_sign_in_path), expected
    end


  end

  # Only the app and com surfaces register a telephone during sign-up; the staff
  # surface has no such step, so it answers with nothing rather than a path.
  { app: true, com: true, org: false }.each do |surface, registers_telephone|
    test "the #{surface} sign-up telephone code page is answered only where the step exists" do
      subject = harness(SignUpSequenceControllerSupport) do
        define_method(:sign_up_surface) { surface }
      end

      path = subject.invoke(:sign_up_telephone_edit_path)

      if registers_telephone
        assert_includes path, "/sign/up/check/telephone/otp"
      else
        assert_equal "/", path
      end
    end
  end
end
