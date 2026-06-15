# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Oidc
      class FrontchannelLogoutsController < ::Core::Com::BareController
        include ::OidcRpLogoutReceiver

        def show
          handle_oidc_frontchannel_logout
        end
      end
    end
  end
end
