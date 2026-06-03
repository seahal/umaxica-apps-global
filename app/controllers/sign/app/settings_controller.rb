# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SettingsController < Sign::RedirectOnlyController
      include ::Sign::SettingsAuthorityRedirect
    end
  end
end
