# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class SettingsController < Sign::RedirectOnlyController
      include ::Sign::SettingsAuthorityRedirect
    end
  end
end
