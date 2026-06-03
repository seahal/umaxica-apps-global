# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      class EmailsController < Sign::RedirectOnlyController
        include ::Sign::SettingsAuthorityRedirect
      end
    end
  end
end
