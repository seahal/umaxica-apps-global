# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Up
      class GuestController < Sign::Org::GuestController
        guest_only! status: :unauthorized,
                    message: I18n.t("sign.org.registration.email.already_logged_in"),
                    no_redirect: true
      end
    end
  end
end
