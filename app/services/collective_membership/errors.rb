# typed: false
# frozen_string_literal: true

module CollectiveMembership
  module Errors
    class Error < StandardError; end

    class DuplicateActiveMembership < Error; end

    class DuplicateActivePrimary < Error; end

    class InvalidUnitTransfer < Error; end

    class InactiveMembership < Error; end
  end

  Error = Errors::Error
  DuplicateActiveMembership = Errors::DuplicateActiveMembership
  DuplicateActivePrimary = Errors::DuplicateActivePrimary
  InvalidUnitTransfer = Errors::InvalidUnitTransfer
  InactiveMembership = Errors::InactiveMembership
end
