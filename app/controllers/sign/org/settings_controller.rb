# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SettingsController < Sign::RedirectOnlyController
      AUTHENTICATION_MODE = :private
      include ::Sign::SettingsAuthorityRedirect
    end
  end
end
