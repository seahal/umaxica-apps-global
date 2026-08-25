# typed: false
# frozen_string_literal: true

module Turnstile
  # Resolves the collaborator that verifies Cloudflare Turnstile tokens.
  #
  # The verifier is injected through configuration rather than referenced directly so the
  # test suite can substitute a stub without the production classes carrying a test-only
  # branch. config/initializers/turnstile.rb names the real verifier; test/test_helper.rb
  # names the stub.
  class VerifierFactory
    def self.current
      verifier = Rails.application.config.x.turnstile.verifier
      if verifier.blank?
        raise RuntimeError,
              "config.x.turnstile.verifier is not configured; set it to a Turnstile verifier class name"
      end

      verifier.to_s.constantize
    end
  end
end
