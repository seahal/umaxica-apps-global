# typed: false
# frozen_string_literal: true

module Sign
  module App
    class CspViolationReportsController < BareController
      include CspViolationReport

      def create
        record_csp_violation!

        head :no_content
      end
    end
  end
end
