# typed: false
# frozen_string_literal: true

module Sign
  module App
    class PreferencesController < Sign::RedirectOnlyController
      include ::Sign::PreferenceAuthorityRedirect
    end
  end
end
