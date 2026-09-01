# typed: false
# frozen_string_literal: true

require "test_helper"

# AGENTS.md: "Keep each surface's controllers, routes, views, policies, sessions and
# state separate... Cross-surface leakage is a security defect."
#
# The seams below are where that separation is actually decided: they name the model
# a controller reads, the column it matches a session on, and the identity records it
# resolves. One wrong constant on one controller is a com request reaching a client
# record, and nothing else in the suite compares them across every controller at once.
# This walks every surface controller and checks its answers belong to its own surface.
class SurfaceIsolationContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  SURFACES = {
    "App" => { prefix: "Client", token_fk: :user_token_id, resource_type: "client" },
    "Com" => { prefix: "Visitor", token_fk: :visitor_token_id, resource_type: "visitor" },
    "Org" => { prefix: "Operator", token_fk: :staff_token_id, resource_type: "operator" },
  }.freeze

  # Seams whose answer must carry the surface's own model prefix.
  NAMESPACED_MODEL_SEAMS = %i(
    verification_model verification_passkey_model identity_email_model
    identity_telephone_model step_up_session_model core_token_class core_resource_class
  ).freeze

  TOKEN_FOREIGN_KEY_SEAMS = %i(verification_token_foreign_key step_up_session_token_foreign_key).freeze

  def self.surface_controllers
    Rails.application.eager_load!
    ActionController::Base.descendants.select { |k| k.name.to_s =~ /\A(?:Auth|Base|Core|Side)::(?:App|Com|Org)::/ }
  end

  def self.surface_of(controller_class) = controller_class.name.split("::")[1]

  # A seam that needs a live request or a signed-in actor is not answerable from a
  # bare instance; those are covered by the request tests instead.
  def answer(controller_class, seam)
    controller_class.allocate.send(seam)
  rescue StandardError, NotImplementedError
    :unanswerable
  end

  # Only the Auth surfaces override the verification seams per surface. Base, Core and
  # Side fall through to VerificationBase, which chooses between Operator and Client --
  # so their com controllers answer ClientVerification. That is asserted as it stands in
  # "the com surfaces outside Auth still resolve verification against client records"
  # below rather than being silently tolerated here.
  def self.auth_surface_controllers
    surface_controllers.select { |k| k.name.start_with?("Auth::") }
  end

  test "every Auth surface controller names models from its own surface" do
    checked = 0
    self.class.auth_surface_controllers.each do |controller_class|
      expected = SURFACES.fetch(self.class.surface_of(controller_class))

      NAMESPACED_MODEL_SEAMS.each do |seam|
        next unless controller_class.private_method_defined?(seam) || controller_class.method_defined?(seam)

        value = answer(controller_class, seam)
        next if value == :unanswerable

        checked += 1

        assert_match(
          /\A#{expected.fetch(:prefix)}/, value.to_s,
          "#{controller_class}##{seam} answered #{value.inspect}, which is not a " \
          "#{expected.fetch(:prefix)} model",
        )
      end
    end

    assert_operator checked, :>, 20, "expected the sweep to reach the Auth surface controllers"
  end

  test "every Auth surface controller matches sessions on its own token column" do
    checked = 0
    self.class.auth_surface_controllers.each do |controller_class|
      expected = SURFACES.fetch(self.class.surface_of(controller_class))

      TOKEN_FOREIGN_KEY_SEAMS.each do |seam|
        next unless controller_class.private_method_defined?(seam) || controller_class.method_defined?(seam)

        value = answer(controller_class, seam)
        next if value == :unanswerable

        checked += 1

        assert_equal expected.fetch(:token_fk), value, "#{controller_class}##{seam}"
      end
    end

    assert_operator checked, :>, 100, "expected the sweep to reach the Auth surface controllers"
  end

  # Pinned as found, not endorsed. VerificationVisitor is an empty wrapper around
  # VerificationBase, so including it does not make verification visitor-scoped: the
  # com controllers outside Auth resolve verification_model to ClientVerification and
  # match on :user_token_id. This only reaches a request through the cookie-backed
  # branch of verification_satisfied?, which runs when the step-up carries no scope.
  test "the com surfaces outside Auth still resolve verification against client records" do
    outside_auth_com =
      self.class.surface_controllers.select do |k|
        k.name =~ /\A(?:Base|Core|Side)::Com::/ &&
          (k.private_method_defined?(:verification_model) || k.method_defined?(:verification_model))
      end

    assert_operator outside_auth_com.size, :>, 50, "expected to reach the com controllers outside Auth"

    outside_auth_com.each do |controller_class|
      value = answer(controller_class, :verification_model)
      next if value == :unanswerable

      assert_equal ClientVerification, value, "#{controller_class}#verification_model"
      assert_equal :user_token_id, answer(controller_class, :verification_token_foreign_key),
                   "#{controller_class}#verification_token_foreign_key"
    end
  end

  test "the core browser boundary reports its own resource type per surface" do
    self.class.surface_controllers.each do |controller_class|
      next unless controller_class.private_method_defined?(:core_resource_type)

      value = answer(controller_class, :core_resource_type)
      next if value == :unanswerable

      expected = SURFACES.fetch(self.class.surface_of(controller_class))

      assert_equal expected.fetch(:resource_type), value, "#{controller_class}#core_resource_type"
    end
  end

  test "the shared step-up seams answer in the shape their callers expect" do
    self.class.surface_controllers.each do |controller_class|
      %i(step_up_supported_methods verification_no_passkey_i18n_key verification_actor_type).each do |seam|
        next unless controller_class.private_method_defined?(seam) || controller_class.method_defined?(seam)

        value = answer(controller_class, seam)
        next if value == :unanswerable

        case seam
        when :step_up_supported_methods
          assert_predicate value, :any?, "#{controller_class}##{seam}"
          assert value.all?(Symbol), "#{controller_class}##{seam} must be symbols"
        else
          assert_predicate value.to_s, :present?, "#{controller_class}##{seam}"
        end
      end
    end
  end
end
