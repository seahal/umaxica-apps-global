# typed: false
# frozen_string_literal: true

module Core
  module App
    module Oidc
      class FrontchannelLogoutsController < ::Core::App::BareController
        include ::OidcRpLogoutReceiver

        def show
          handle_oidc_frontchannel_logout
        end
      end
    end
  end
end
