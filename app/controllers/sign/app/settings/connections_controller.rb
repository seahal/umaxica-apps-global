# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class ConnectionsController < Sign::RedirectOnlyController
        include ::Sign::SettingsAuthorityRedirect
      end
    end
  end
end
