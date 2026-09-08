# typed: false
# frozen_string_literal: true

module Eid
  module Net
    class RevisionsController < BareController
      include ::ApplicationRevisionRendering

      AUTHENTICATION_MODE = :bare

      def show
        render_revision
      end
    end
  end
end
