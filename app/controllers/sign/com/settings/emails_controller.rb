# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class EmailsController < Sign::RedirectOnlyController
        AUTHENTICATION_MODE = :private
        include ::Sign::SettingsAuthorityRedirect
      end
    end
  end
end
