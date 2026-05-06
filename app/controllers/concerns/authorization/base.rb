# typed: false
# frozen_string_literal: true

module Authorization
  module Base
    extend ActiveSupport::Concern

    private

    # Action Policy is the authorization layer for this app; no request-specific work here.
    def authorize_request!
      true
    end
  end
end
