# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Oidc
      module Backchannel
        class LogoutsController < ::Core::Com::BareController
          include ::OidcRpLogoutReceiver

          AUTHENTICATION_MODE = :bare

          protect_from_forgery with: :null_session

          def create
            handle_oidc_backchannel_logout
          end
        end
      end
    end
  end
end
