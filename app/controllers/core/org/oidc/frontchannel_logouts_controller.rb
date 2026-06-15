# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Oidc
      class FrontchannelLogoutsController < ::Core::Org::BareController
        include ::OidcRpLogoutReceiver

        def show
          handle_oidc_frontchannel_logout
        end
      end
    end
  end
end
