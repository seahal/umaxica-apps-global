# typed: false
# frozen_string_literal: true

module Palm
  module App
    class SignOutsController < Palm::App::BareController
      AUTHENTICATION_MODE = :bare

      def show
        response.set_header("Cache-Control", "no-store")
        response.set_header("Referrer-Policy", "no-referrer")
        @logout_transaction = logout_transaction
        if @logout_transaction.present? && @logout_transaction.finalized? && palm_logout_state_matches?
          return render "palm/app/sign_outs/show", status: :ok
        end

        return render plain: "Invalid logout state", status: :unprocessable_content if params[:state].present?
        return render plain: "Logout pending", status: :accepted if @logout_transaction.present?

        render "palm/app/sign_outs/show", status: :ok
      end

      def create
        response.set_header("Cache-Control", "no-store")
        response.set_header("Referrer-Policy", "no-referrer")
        result = PalmLogoutCoordinator.call(request: request, ri: params[:ri])
        return render json: { error: result.error, error_description: result.error_description },
                      status: :unauthorized unless result.success?

        render json: {
          logout_url: result.logout_url,
          state: result.state,
          expires_at: result.expires_at&.iso8601,
        }, status: :ok
      end

      private

      def logout_transaction
        return if params[:logout_challenge].blank?

        AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: params.expect(:logout_challenge))
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def palm_logout_state_matches?
        return true if @logout_transaction.blank? || @logout_transaction.callback_state.blank?
        return false if params[:state].blank?

        ActiveSupport::SecurityUtils.secure_compare(
          @logout_transaction.callback_state,
          params[:state].to_s,
        )
      end
    end
  end
end
