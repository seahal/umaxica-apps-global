# typed: false
# frozen_string_literal: true

module Eid
  module Net
    class RootsController < BareController
      AUTHENTICATION_MODE = :bare

      allow_browser versions: :modern
      layout false

      def index
      end
    end
  end
end
