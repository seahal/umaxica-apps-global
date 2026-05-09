# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class TelephonesController < ApplicationController
        auth_required!

        include Sign::TelephoneRegistrable
        include ::Verification::User

        before_action :authenticate_user!

        def index
          @user_telephones = current_user.user_telephones
        end

        def new
          @user_telephone = UserTelephone.new
        end

        def edit
          @user_telephone = current_user.user_telephones.find_by!(public_id: params.expect(:id))
        end

        def create
          user = current_user
          return head :unauthorized if user.blank?

          tel_params = params.expect(user_telephone: [:raw_number, :number])
          number = tel_params[:raw_number] || tel_params[:number]
          if initiate_telephone_verification(user, number, auto_accept_confirmations: true)
            redirect_to(edit_sign_app_configuration_telephone_path(@user_telephone.id))
          else
            render :new, status: :unprocessable_content
          end
        end

        def destroy
          telephone = current_user.user_telephones.find_by!(public_id: params.expect(:id))

          unless AuthMethodGuard.can_remove_telephone?(current_user, telephone)
            redirect_to(
              sign_app_configuration_telephones_path,
              alert: t("sign.app.configuration.telephone.destroy.last_method"),
            )
            return
          end

          telephone.destroy!
          create_audit_event!(UserChronicleEvent::TELEPHONE_REMOVED, subject: telephone)

          redirect_to(
            sign_app_configuration_telephones_path,
            notice: t("sign.app.configuration.telephone.destroy.success"),
            status: :see_other,
          )
        end

        private

        def create_audit_event!(event_id, subject:)
          ChronicleRecord.connected_to(role: :writing) do
            UserChronicleEvent.find_or_create_by!(id: event_id)
            UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
          end

          UserChronicle.create!(
            actor_type: "User",
            actor_id: current_user.id,
            event_id: event_id,
            subject_id: subject.id.to_s,
            subject_type: subject.class.name,
            occurred_at: Time.current,
          )
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "configuration_telephone"
        end
      end
    end
  end
end
