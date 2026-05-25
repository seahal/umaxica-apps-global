# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      class GuestController < Sign::App::GuestController
        AUTHENTICATION_MODE = :guest

        declare_authentication_mode! :guest, status: :unauthorized, no_redirect: true
      end
    end
  end
end
