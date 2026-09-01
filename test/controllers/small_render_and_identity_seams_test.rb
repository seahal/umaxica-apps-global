# typed: false
# frozen_string_literal: true

require "test_helper"

# A last group of one-line seams: the template each surface answers a logout
# confirmation with, the staff verification fallback, and the public identifier
# a session endpoint puts on the wire -- which must fail loudly rather than fall
# back to an internal row id.
class SmallRenderAndIdentitySeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(concern_or_class, &definition)
    base = concern_or_class.is_a?(Module) && !concern_or_class.is_a?(Class) ? ActionController::Base : concern_or_class
    Class.new(base) do
      include concern_or_class if concern_or_class.is_a?(Module) && !concern_or_class.is_a?(Class)

      attr_accessor :params_hash, :rendered

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new.tap do |h|
      h.params_hash = { ri: "jp" }
      h.request = ActionDispatch::TestRequest.create
    end
  end

  test "the logout confirmation and completion are answered from the controller's own template" do
    subject = harness(SignOidcLogout)

    assert_equal :show, subject.invoke(:oidc_logout_completion_template)

    subject.invoke(:render_oidc_end_session_confirmation)

    assert_equal [[:show], { status: :ok }], subject.rendered
  end

  test "the staff verification fallback returns to the staff verification entry point" do
    subject = harness(SignOrgVerificationBase)

    assert_includes subject.invoke(:verification_unavailable_redirect_path), "/verification"
  end

  test "a session endpoint refuses to put an internal row id on the wire" do
    [Core::Com::Api::V0::SessionsController, Core::Org::Api::V0::SessionsController].each do |controller_class|
      subject = harness(controller_class) do
        def current_resource = Struct.new(:public_id).new("")
      end

      assert_raises(StandardError) { subject.invoke(:actor_public_id) }
    end
  end
end
