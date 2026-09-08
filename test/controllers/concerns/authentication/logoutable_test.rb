# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Authentication
  class LogoutableTest < ActiveSupport::TestCase
    # ------------------------------------------------------------------
    # Regression coverage for "ordinary logout must not revoke other
    # sessions" (S-0). If it regresses, this test fails loudly.
    # ------------------------------------------------------------------
    test "Oidc::SingleLogoutService is intentionally absent" do
      # The misleadingly-named Oidc::SingleLogoutService used to live at
      # `app/services/oidc/single_logout_service.rb` and revoked every
      # active token for the actor. It was deleted because (a) its name
      # promised OIDC SLO-protocol semantics while doing something else,
      # and (b) its only correct use case is already covered by
      # AuthenticationLogoutAllSessions. If this guard fails it means
      # someone re-added the class -- keep the deletion and use
      # LogoutAllSessions from a dedicated endpoint instead.
      assert_not defined?(Oidc::SingleLogoutService),
                 "Oidc::SingleLogoutService must remain deleted. See " \
                 "adr/logout-primitive-and-composition.md."
    end
  end
end
