# typed: false
# frozen_string_literal: true

module ExternalSignIn
  # Raised by OrgEntraResolver when the (tid, oid) pair has no pre-provisioned
  # OperatorEntraIdentity, or when the identity or its connection is not ACTIVE.
  # Never raised during provisioning — only during a sign-in attempt.
  class IdentityNotFoundError < StandardError; end
end
