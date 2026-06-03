# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class PreferencesController < Sign::RedirectOnlyController
      include ::Sign::PreferenceAuthorityRedirect
    end
  end
end
