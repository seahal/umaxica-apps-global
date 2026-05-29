# typed: false
# frozen_string_literal: true

module Authorization
  module Base
    extend ActiveSupport::Concern

    private

    # Action Policy is the authorization layer for this app. This legacy request
    # hook must never act as an implicit allow.
    def authorize_request!
      raise "Authorization::Base#authorize_request! is disabled; authorize through Action Policy"
    end
  end
end
