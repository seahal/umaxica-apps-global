# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SettingsController < Sign::RedirectOnlyController
      include ::SignSettingsAuthorityRedirect

      AUTHENTICATION_MODE = :private
    end
  end
end
