# typed: false
# frozen_string_literal: true

module Acme
  # acme/www owns refresh token rotation; the inherited implementation
  # preserves the existing replay, family-revoke, and audit semantics.
  class RefreshTokenService < ::Sign::RefreshTokenService
  end
end
