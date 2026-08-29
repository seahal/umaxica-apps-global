# typed: false
# frozen_string_literal: true

class TokenEmergencyService
  # TODO: Implement token emergency service
  # - execute emergency token operations per surface (access_reset, refresh_freeze)
  # - record audit logs
  # - return the execution result (token_version, etc)
  def self.call!(*)
    raise NotImplementedError, "TokenEmergencyService.call! is not implemented yet"
  end
end
