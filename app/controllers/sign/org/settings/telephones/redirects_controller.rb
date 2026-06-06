# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      module Telephones
        class RedirectsController < ::Sign::RedirectOnlyController
          include ::SignSettingsAuthorityRedirect

          AUTHENTICATION_MODE = :private
        end
      end
    end
  end
end
