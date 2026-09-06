# typed: false
# frozen_string_literal: true

# This application does not use Rails flash (generic/no-flash-messages.mdc):
# feedback is rendered inline in the response, so there is no cross-subdomain
# flash to bound and no boundary machinery here.
#
# `reset_flash` does nothing. It is named by `before_action :reset_flash` in the
# surface application controllers, so it is load-bearing only as a callback
# target; it clears nothing and enforces nothing. Removing it means removing
# those declarations too. Kept as-is because it is inert, not because it
# provides a guarantee.

module Session
  extend ActiveSupport::Concern

  def reset_flash
    nil
  end
end
