# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignComVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  test "included do does not include SignAppVerificationBase module" do
    klass =
      Class.new(ApplicationController) do
        include AuthenticationBase
        include PreferenceBase
        include AuthenticationVisitor
        include VerificationVisitor
        include SignEmailOtpVerificationSupport
        include SignComVerificationBase
      end

    assert_not_includes klass.included_modules, SignAppVerificationBase
  end

  test "included do includes visitor verification dependencies directly" do
    klass =
      Class.new(ApplicationController) do
        include AuthenticationBase
        include PreferenceBase
        include AuthenticationVisitor
        include VerificationVisitor
        include SignEmailOtpVerificationSupport
        include SignComVerificationBase
      end

    assert_includes klass.included_modules, AuthenticationVisitor
    assert_includes klass.included_modules, VerificationVisitor
    assert_includes klass.included_modules, SignEmailOtpVerificationSupport
  end
end

# SignComVerificationBase::Overrides (prepended by the real controller) overrides
# VerificationBase#verification_model, #verification_token_foreign_key, and
# #current_verification_actor, but the bare SignComVerificationBase module included here does not --
# only its nested Overrides submodule does. A controller with VerificationVisitor + SignComVerificationBase
# (no Overrides) therefore reaches VerificationBase's own non-operator branches for those methods directly.
class SignComVerificationBaseDirectCoverageTest < ActiveSupport::TestCase
  # VerificationBase#verification_model / #verification_token_foreign_key only distinguish
  # actor_operator? true/false -- the false branch always resolves to ClientVerification /
  # :user_token_id. There is no visitor-specific case in VerificationBase itself; VisitorVerification /
  # :visitor_token_id come entirely from SignComVerificationBase::Overrides, not from this method.
  test "verification_model resolves ClientVerification for non-operator actors" do
    klass =
      Class.new(ApplicationController) do
        include VerificationVisitor
        include SignComVerificationBase
      end
    controller = klass.new

    assert_equal ClientVerification, controller.send(:verification_model)
  end

  test "verification_token_foreign_key resolves user_token_id for non-operator actors" do
    klass =
      Class.new(ApplicationController) do
        include VerificationVisitor
        include SignComVerificationBase
      end
    controller = klass.new

    assert_equal :user_token_id, controller.send(:verification_token_foreign_key)
  end

  test "current_verification_actor returns nil when no actor reader is defined" do
    klass =
      Class.new(ApplicationController) do
        include VerificationVisitor
        include SignComVerificationBase
      end
    controller = klass.new

    assert_nil controller.send(:current_verification_actor)
  end
end
