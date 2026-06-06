# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Web
      module V0
        module In
          module Telephone
            class OtpsController < ::Sign::App::ApplicationController
              AUTHENTICATION_MODE = :guest

              def create
                result = SignInOtpResendService.new(kind: :telephone, state: otp_params[:state]).call
                render_result(result)
              end

              private

              def otp_params
                params.permit(:state)
              end

              def render_result(result)
                response.headers["Retry-After"] =
                  result.retry_after.to_s if result.status == :too_many_requests
                render json: {
                  resendable: result.resendable,
                  retry_after: result.retry_after,
                }, status: result.status
              end
            end
          end
        end
      end
    end
  end
end
