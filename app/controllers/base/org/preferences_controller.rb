# typed: false
# frozen_string_literal: true

module Base
  module Org
    class PreferencesController < PreferencesBaseController
      AUTHENTICATION_MODE = :open

      def show
        render "base/shared/preferences/show"
      end
    end
  end
end
