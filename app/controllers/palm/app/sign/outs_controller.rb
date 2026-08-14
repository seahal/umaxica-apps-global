# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Sign
      class OutsController < Palm::App::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :bare

        def show
          response.set_header("Cache-Control", "no-store")
          response.set_header("Referrer-Policy", "no-referrer")
          # The confirmation screen used to carry `<meta name="robots">` in its own <head>; the
          # Inertia shell owns the document now, so the same instruction is sent as a header.
          response.set_header("X-Robots-Tag", "noindex, nofollow")
          @logout_transaction = logout_transaction
          if @logout_transaction.present? && @logout_transaction.finalized? && palm_logout_state_matches?
            return render_sign_out_page
          end

          return render plain: "Invalid logout state", status: :unprocessable_content if params[:state].present?
          return render plain: "Logout pending", status: :accepted if @logout_transaction.present?

          render_sign_out_page
        end

        def create
          response.set_header("Cache-Control", "no-store")
          response.set_header("Referrer-Policy", "no-referrer")
          result = PalmLogoutCoordinator.call(request: request, ri: current_region_identifier)
          return render json: { error: result.error, error_description: result.error_description },
                        status: :unauthorized unless result.success?

          render json: {
            logout_url: result.logout_url,
            state: result.state,
            expires_at: result.expires_at&.iso8601,
          }, status: :ok
        end

        private

        # The page component keeps the name the template had, so the Palm surface resolves it from
        # src/pages/palm/app/sign_outs/show.tsx rather than from the controller's nested path.
        def render_sign_out_page
          render inertia: "palm/app/sign_outs/show", props: sign_out_page_props, status: :ok
        end

        def sign_out_page_props
          {
            title: t("palm.app.sign_out.heading"),
            heading: t("palm.app.sign_out.heading"),
            description:
              if @logout_transaction.present?
                t("palm.app.sign_out.completed")
              else
                t("palm.app.sign_out.missing")
              end,
            state: (params[:state].to_s if @logout_transaction.present? && params[:state].present?),
          }
        end

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
end
