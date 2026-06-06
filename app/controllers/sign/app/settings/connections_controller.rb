# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class ConnectionsController < Sign::RedirectOnlyController
        include ::SignSettingsAuthorityRedirect

        AUTHENTICATION_MODE = :private
      end
    end
  end
end
