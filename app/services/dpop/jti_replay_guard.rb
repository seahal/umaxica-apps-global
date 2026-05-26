# typed: false
# frozen_string_literal: true

module Dpop
  class JtiReplayGuard
    def self.record!(jti, resource_type: "client", jkt: nil, htm: nil, htu: nil)
      return false if jti.blank?

      Dpop::ProofStateStore.for(resource_type).record_jti!(jti: jti, jkt: jkt, htm: htm, htu: htu)
    end
  end
end
