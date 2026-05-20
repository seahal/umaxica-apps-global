# typed: false
# frozen_string_literal: true

module Sign
  module App
    module In
      class EmailGuestController < GuestController
        guest_only! status: :bad_request,
                    message: I18n.t("sign.app.authentication.email.new.you_have_already_logged_in"),
                    no_redirect: true
      end
    end
  end
end
