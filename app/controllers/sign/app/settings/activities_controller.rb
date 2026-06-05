# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class ActivitiesController < Sign::RedirectOnlyController
        include ::Sign::SettingsAuthorityRedirect

        AUTHENTICATION_MODE = :private
      end
    end
  end
end
