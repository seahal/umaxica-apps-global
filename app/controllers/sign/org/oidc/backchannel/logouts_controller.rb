# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Oidc
      module Backchannel
        class LogoutsController < ::Sign::Org::BareController
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
