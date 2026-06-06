# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Up
      class InvitationsController < Sign::Org::ApplicationController
        include CloudflareTurnstile

        AUTHENTICATION_MODE = :guest

        def new
          @invitation_code = params[:invitation_code].to_s
        end

        def create
          @invitation_code = params[:invitation_code].to_s

          unless cloudflare_turnstile_validation["success"]
            flash.now[:alert] = t(".turnstile_failed")
            render :new, status: :unprocessable_content
            return
          end

          result = ::OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation_code)

          if result.success?
            redirect_to(
              new_sign_org_sign_in_path,
              notice: t(".success", public_id: result.operator.public_id),
            )
          else
            flash.now[:alert] = result.error
            render :new, status: :unprocessable_content
          end
        end
      end
    end
  end
end
