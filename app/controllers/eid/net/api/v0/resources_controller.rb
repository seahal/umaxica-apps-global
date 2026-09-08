# typed: false
# frozen_string_literal: true

module Eid
  module Net
    module Api
      module V0
        class ResourcesController < Eid::Net::BareController
          include ::ProblemDetailsRendering
          include ::ApiContentNegotiation

          AUTHENTICATION_MODE = :bare
          MAXIMUM_EID_BYTES = 255

          before_action { response.set_header("Cache-Control", "no-store") }

          def show
            eid = params.expect(:eid).to_s
            return render_problem(:bad_request) unless transport_safe_eid?(eid)

            render_problem(:not_found)
          end

          private

          # This protects the HTTP boundary without selecting an issuance format. Future EIDs remain
          # opaque; the route only refuses blank, invalidly encoded, control-bearing, or oversized
          # path components that cannot safely participate in resolution.
          def transport_safe_eid?(eid)
            eid.present? && eid.valid_encoding? && eid.bytesize <= MAXIMUM_EID_BYTES && !eid.match?(/[\p{Cc}\s]/)
          end
        end
      end
    end
  end
end
