# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class ActivitiesController < Sign::RedirectOnlyController
        include ::Sign::SettingsAuthorityRedirect
      end
    end
  end
end
