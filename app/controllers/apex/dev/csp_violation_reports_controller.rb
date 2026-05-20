# typed: false
# frozen_string_literal: true

module Apex
  module Dev
    class CspViolationReportsController < BareController
      include CspViolationReport

      def create
        record_csp_violation!

        head :no_content
      end
    end
  end
end
