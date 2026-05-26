# typed: false
# frozen_string_literal: true

module Dpop
  class NonceService
    def self.generate(resource_type: "client")
      Dpop::ProofStateStore.for(resource_type).issue_nonce!
    end

    def self.verify(nonce, resource_type: "client")
      Dpop::ProofStateStore.for(resource_type).consume_nonce!(nonce)
    end
  end
end
