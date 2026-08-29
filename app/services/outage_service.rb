# typed: false
# frozen_string_literal: true

class OutageService
  # TODO: Implement outage service
  # - store and retrieve outage state per surface
  # - write audit logs
  # - decide where to propagate the state (DB/Redis/FeatureFlag)
  # - align allowed routes during outages (owner/**, /up, etc) with the design
  def self.update!(*)
    raise NotImplementedError, "OutageService.update! is not implemented yet"
  end
end
