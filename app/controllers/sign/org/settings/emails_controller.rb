# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      class EmailsController < Sign::RedirectOnlyController
        include ::Sign::SettingsAuthorityRedirect

        AUTHENTICATION_MODE = :private
      end
    end
  end
end
