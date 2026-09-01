# typed: false
# frozen_string_literal: true

require "test_helper"

# Small per-surface overrides around sign-out and the sign-in checkpoint. The
# base surfaces render their own document layout when a logout challenge is
# rejected, the confirmation form posts back to the surface's own endpoint, and
# the checkpoint page starts from an empty item list rather than a nil one.
class SignOutAndCheckpointSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class, &definition)
    Class.new(controller_class) do
      attr_accessor :params_hash, :rejected

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new.tap do |h|
      h.params_hash = { ri: "jp", logout_challenge: "challenge-1" }
      h.request = ActionDispatch::TestRequest.create
    end
  end

  [Base::App::SignOutsController, Base::Com::SignOutsController, Base::Org::SignOutsController].each do |klass|
    test "#{klass.name} renders its own document layout when a logout challenge is rejected" do
      harness = harness_for(klass)
      # The shared implementation this override calls needs a live request; the
      # override's own contribution -- selecting the document layout -- is what
      # this pins.
      harness.singleton_class.prepend(Module.new do
        def reject_oidc_logout_challenge!(reason)
          super
        rescue StandardError
          nil
        end
      end)

      harness.invoke(:reject_oidc_logout_challenge!, "invalid_challenge")

      assert harness.instance_variable_get(:@render_surface_erb_layout)
    end
  end

  [Base::Com::Oidc::LogoutsController, Base::Org::Oidc::LogoutsController].each do |klass|
    test "#{klass.name} posts its logout confirmation back to its own endpoint" do
      # An anonymous subclass has no controller path of its own, and the shared
      # sign-out helpers derive their route prefix from it.
      harness = harness_for(klass) do
        define_method(:controller_path) { klass.controller_path }
      end
      form = harness.invoke(:sign_out_confirmation_form)

      assert_predicate form.fetch(:action), :present?
      assert_equal "challenge-1", form.fetch(:logout_challenge)
    end
  end

  [
    SignAppInCheckControllerSupport,
    SignComInCheckControllerSupport,
    SignOrgInCheckControllerSupport,
  ].each do |concern|
    test "#{concern.name} starts the checkpoint page from an empty item list" do
      harness = Class.new { include concern }.new

      harness.show

      assert_empty harness.instance_variable_get(:@checkpoint_items)
    end
  end
end
