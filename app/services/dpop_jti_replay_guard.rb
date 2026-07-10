# typed: false
# frozen_string_literal: true

class DpopJtiReplayGuard
  def self.record!(jti, resource_type: "client", jkt: nil, htm: nil, htu: nil)
    return false if jti.blank?

    DpopProofStateStore.for(resource_type).record_jti!(jti: jti, jkt: jkt, htm: htm, htu: htu)
  end
end
