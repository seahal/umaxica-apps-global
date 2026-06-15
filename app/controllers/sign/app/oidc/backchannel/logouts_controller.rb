# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Oidc
      module Backchannel
        class LogoutsController < ::Sign::App::BareController
          AUTHENTICATION_MODE = :bare

          include ::OidcRpLogoutReceiver

          protect_from_forgery with: :null_session

          def create
            handle_oidc_backchannel_logout
          end
        end
      end
    end
  end
end
