# typed: false
# frozen_string_literal: true

module Acme
  module Dev
    class CspViolationReportsController < BareController
      include CspViolationReport

      AUTHENTICATION_MODE = :bare

      def create
        record_csp_violation!

        head :no_content
      end
    end
  end
end
