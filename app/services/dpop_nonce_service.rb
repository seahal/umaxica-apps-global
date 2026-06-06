# typed: false
# frozen_string_literal: true

class DpopNonceService
  def self.generate(resource_type: "client")
    DpopProofStateStore.for(resource_type).issue_nonce!
  end

  def self.verify(nonce, resource_type: "client")
    DpopProofStateStore.for(resource_type).consume_nonce!(nonce)
  end
end
