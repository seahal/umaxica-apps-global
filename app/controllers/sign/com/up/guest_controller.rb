# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      class GuestController < Sign::Com::GuestController
        AUTHENTICATION_MODE = :guest

        declare_authentication_mode! :guest, status: :unauthorized, no_redirect: true

        prepend_before_action :reject_logged_in_session,
                              if: -> { %i(new create).include?(action_name.to_sym) }
      end
    end
  end
end
