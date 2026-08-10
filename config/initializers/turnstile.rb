# frozen_string_literal: true

# The Turnstile verifier is resolved through Turnstile::VerifierFactory rather than being
# referenced by name at the call sites, so the collaborator is an injected dependency.
# Named as a string because the verifier lives in lib/ and must not be autoloaded during
# initialization.
Rails.application.config.x.turnstile.verifier = "JitSecurityTurnstileVerifier"
