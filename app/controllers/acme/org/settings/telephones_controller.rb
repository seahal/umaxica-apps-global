# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Settings
      class TelephonesController < Acme::Org::ApplicationController
        include ::VerificationOperator

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!
        before_action :authorize_telephones!, only: :index

        def index
          @staff_telephones = current_operator.staff_telephones.order(created_at: :asc)
        end

        def destroy
          @staff_telephone = current_operator.staff_telephones.find(params(:id))
          authorize!(@staff_telephone)

          unless AuthMethodGuard.can_remove_telephone?(current_operator, @staff_telephone)
            redirect_to(
              acme_org_settings_telephones_path(ri: params[:ri]),
              alert: t("sign.org.settings.telephone.destroy.last_method"),
            )
            return
          end

          @staff_telephone.destroy!
          redirect_to(
            acme_org_settings_telephones_path(ri: params[:ri]),
            notice: t("sign.org.settings.telephone.destroy.success"),
            status: :see_other,
          )
        end

        private

        def authorize_telephones!
          authorize!(OperatorTelephone, to: :index?)
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "settings_telephone"
        end
      end
    end
  end
end
