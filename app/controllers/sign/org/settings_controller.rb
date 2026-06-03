# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SettingsController < Sign::RedirectOnlyController
      include ::Sign::SettingsAuthorityRedirect
    end
  end
end
