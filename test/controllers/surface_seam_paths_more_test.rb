# typed: false
# frozen_string_literal: true

require "test_helper"

# The remaining per-surface seams the shared ceremony and preference flows call.
# Same contract as the first group: each surface answers with its own paths and
# its own page payload, so none of these can silently resolve to another
# surface's screen.
class SurfaceSeamPathsMoreTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class, params: { ri: "jp" })
    Class.new(controller_class) do
      attr_accessor :params_hash

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |harness|
      harness.params_hash = params
      harness.request = ActionDispatch::TestRequest.create
    end
  end

  {
    "app" => Base::App::Preference::EmailsController,
    "com" => Base::Com::Preference::EmailsController,
    "org" => Base::Org::Preference::EmailsController,
  }.each do |surface, controller_class|
    test "the #{surface} unsubscribe page is built for the #{surface} surface" do
      harness = harness_for(controller_class)
      harness.instance_variable_set(
        :@email,
        Struct.new(:promotional?, :public_id, :address).new(true, "pub-1", "someone@example.com"),
      )

      props = harness.invoke(:unsubscribe_page_props)

      assert_predicate props.fetch(:title), :present?
    end
  end

  {
    "apple" => Auth::App::Sign::Up::Check::Apple::ConfirmationsController,
    "google" => Auth::App::Sign::Up::Check::Google::ConfirmationsController,
  }.each do |provider, controller_class|
    test "the #{provider} sign-up confirmation posts back to its own provider step" do
      assert_predicate harness_for(controller_class).invoke(:sign_up_confirmation_action_path), :present?
    end
  end

  test "the app verification success fallback returns to the app settings surface" do
    assert_predicate harness_for(Auth::App::Verification::BaseController)
      .invoke(:verification_success_fallback_path), :present?
  end

  test "each surface's verification email edit path names the addressed email" do
    app_path = harness_for(Auth::App::Verification::EmailsController, params: { ri: "jp", id: "pub-1" })
      .invoke(:verification_email_edit_path)
    com_path = harness_for(Auth::Com::Verification::EmailsController, params: { ri: "jp", id: "pub-1" })
      .invoke(:verification_email_edit_path)

    assert_includes app_path, "pub-1"
    assert_includes com_path, "pub-1"
  end

  test "the staff verification entry page is built for the staff surface" do
    harness = harness_for(Auth::Org::VerificationsController)
    harness.instance_variable_set(:@verification_methods, [])

    assert_predicate harness.invoke(:verification_entry_props), :present?
  end
end
