# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Oidc
      class FrontchannelLogoutsController < ::Sign::Org::BareController
        include ::OidcRpLogoutReceiver

        def show
          handle_oidc_frontchannel_logout
        end
      end
    end
  end
end
