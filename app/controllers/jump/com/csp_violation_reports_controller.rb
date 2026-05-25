# typed: false
# frozen_string_literal: true

module Jump
  module Com
    class CspViolationReportsController < BareController
      AUTHENTICATION_MODE = :bare

      include CspViolationReport

      def create
        record_csp_violation!

        head :no_content
      end
    end
  end
end
