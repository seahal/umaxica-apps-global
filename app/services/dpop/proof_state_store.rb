# typed: false
# frozen_string_literal: true

module Dpop
  class ProofStateStore
    def self.for(resource_type)
      case resource_type.to_s
      when "operator" then OperatorDpopProofState
      when "visitor" then VisitorDpopProofState
      else ClientDpopProofState
      end
    end
  end
end
