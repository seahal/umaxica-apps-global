# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class ConnectionsController < Sign::RedirectOnlyController
        include ::Sign::SettingsAuthorityRedirect

        AUTHENTICATION_MODE = :private
      end
    end
  end
end
