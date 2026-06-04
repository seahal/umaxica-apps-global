# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class PreferencesController < PreferencesBaseController
      AUTHENTICATION_MODE = :open

      def show
        render "acme/shared/preferences/show"
      end
    end
  end
end
