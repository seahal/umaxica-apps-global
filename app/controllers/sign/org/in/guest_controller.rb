# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module In
      class GuestController < Sign::Org::GuestController
        AUTHENTICATION_MODE = :guest

        declare_authentication_mode! :guest, status: :unauthorized, no_redirect: true
      end
    end
  end
end
