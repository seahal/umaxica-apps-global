# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      module Telephones
        class RedirectsController < Sign::RedirectOnlyController
          include ::Sign::SettingsAuthorityRedirect

          AUTHENTICATION_MODE = :private
        end
      end
    end
  end
end
