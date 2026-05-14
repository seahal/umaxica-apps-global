# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class CspViolationReportsController < PublicController
      include CspViolationReport

      public_strict!

      skip_before_action :canonicalize_query_params, raise: false
      skip_before_action :set_region, raise: false

      def create
        record_csp_violation!

        head :no_content
      end
    end
  end
end
