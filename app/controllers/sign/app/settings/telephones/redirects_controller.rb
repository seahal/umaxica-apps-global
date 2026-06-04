# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      module Telephones
        class RedirectsController < Sign::RedirectOnlyController
          AUTHENTICATION_MODE = :private
          include ::Sign::SettingsAuthorityRedirect
        end
      end
    end
  end
end
