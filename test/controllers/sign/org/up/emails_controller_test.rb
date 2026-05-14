# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Up::EmailsControllerTest < ActiveSupport::TestCase
  test "new builds staff email and clears invitation session" do
    controller = build_controller
    controller.session[Sign::Org::Up::EmailsController::INVITATION_SESSION_KEY] = "old-code"

    controller.new

    assert_instance_of OperatorEmail, controller.instance_variable_get(:@staff_email)
    assert_nil controller.session[Sign::Org::Up::EmailsController::INVITATION_SESSION_KEY]
  end

  test "create renders new when invitation code is blank" do
    controller = build_controller(invitation_code: " ")

    controller.create

    staff_email = controller.instance_variable_get(:@staff_email)

    assert_predicate staff_email.errors[:base], :present?
    assert_equal [:new, { status: :unprocessable_content }], controller.render_call
  end

  test "create renders new when invitation is rejected" do
    controller = build_controller(invitation_code: "bad-code")

    Org::RegistrationPolicy.stub(
      :validate!, ->(**) {
                    raise Org::RegistrationPolicy::InvalidInvitationError, "bad invitation"
                  },
    ) do
      controller.create
    end

    staff_email = controller.instance_variable_get(:@staff_email)

    assert_equal ["bad invitation"], staff_email.errors[:base]
    assert_equal [:new, { status: :unprocessable_content }], controller.render_call
  end

  test "create renders new when turnstile fails" do
    I18n.backend.store_translations(
      :ja,
      sign: { org: { registration: { email: { turnstile_failed: "turnstile failed" } } } },
    )
    controller = build_controller(
      invitation_code: "INVITE-CODE",
      staff_email: { raw_address: "invitee@example.com" },
      turnstile_success: false,
    )

    Org::RegistrationPolicy.stub(:validate!, true) do
      controller.create
    end

    staff_email = controller.instance_variable_get(:@staff_email)

    assert_equal "invitee@example.com", staff_email.address
    assert_predicate staff_email.errors[:base], :present?
    assert_equal [:new, { status: :unprocessable_content }], controller.render_call
  end

  test "create stores normalized invitation and redirects when valid" do
    controller = build_controller(invitation_code: " INVITE-CODE ")

    Org::RegistrationPolicy.stub(:validate!, true) do
      controller.create
    end

    assert_equal "invite-code", controller.session[Sign::Org::Up::EmailsController::INVITATION_SESSION_KEY]
    assert_equal ["/sign/up/invitations/emails/new?invitation_code=invite-code", {}], controller.redirect_call
  end

  private

  def build_controller(invitation_code: nil, staff_email: {}, turnstile_success: true)
    params = Object.new
    params.define_singleton_method(:expect) { |key| (key == :invitation_code) ? invitation_code : nil }
    params.define_singleton_method(:permit) do |permitted|
      ActionController::Parameters.new(staff_email: staff_email).permit(permitted)
    end
    controller = Sign::Org::Up::EmailsController.new
    session = {}
    controller.define_singleton_method(:params) { params }
    controller.define_singleton_method(:session) { session }
    controller.define_singleton_method(:cloudflare_turnstile_validation) { { "success" => turnstile_success } }
    controller.define_singleton_method(:new_sign_org_up_email_path) do |path_params = {}|
      "/sign/up/invitations/emails/new?#{path_params.to_query}"
    end
    controller.define_singleton_method(:render) { |template, **options| self.render_call = [template, options] }
    controller.define_singleton_method(:redirect_to) { |path, **options| self.redirect_call = [path, options] }
    controller.singleton_class.attr_accessor :render_call, :redirect_call
    controller
  end
end
