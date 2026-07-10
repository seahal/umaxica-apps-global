# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module Up
        class InvitationsController < ::Auth::Org::ApplicationController
          include CloudflareTurnstile

          AUTHENTICATION_MODE = :guest

          def new
            @invitation_code = params[:invitation_code].to_s
          end

          def create
            @invitation_code = params[:invitation_code].to_s

            unless cloudflare_turnstile_validation["success"]
              @form_error = t(".turnstile_failed")
              render :new, status: :unprocessable_content
              return
            end

            result = ::OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation_code)

            if result.success?
              redirect_to(auth_org_sign_in_path)
            else
              @form_error = result.error
              render :new, status: :unprocessable_content
            end
          end
        end
      end
    end
  end
end
