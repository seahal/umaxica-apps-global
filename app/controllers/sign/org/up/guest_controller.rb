# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Up
      class GuestController < Sign::Org::GuestController
        AUTHENTICATION_MODE = :guest

        declare_authentication_mode! :guest, status: :unauthorized,
                    message: I18n.t("sign.org.registration.email.already_logged_in"),
                    no_redirect: true
      end
    end
  end
end
