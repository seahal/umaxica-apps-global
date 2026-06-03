# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class TelephonesController < Sign::App::ApplicationController
        include Common::Redirect
        include Common::Otp
        include Sign::TelephoneRegistrable

        include ::Verification::Client

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        # Object-level authorization (ActionPolicy): index/new/create gate the actor type; edit/destroy
        # authorize the owned record (find_by! is owner-scoped, so a non-owner gets 404 first).
        # Verification guards remain in place.
        before_action :authorize_telephones!, only: %i(index)
        before_action :authorize_telephone_registration!, only: %i(new create)

        def index
          @client_telephones = current_client.client_telephones
        end

        def new
          @user_telephone = ClientTelephone.new
        end

        def edit
          @user_telephone = current_client.client_telephones.find_by!(public_id: params(:id))
          authorize!(@user_telephone)
        end

        def create
          user = current_client
          return head :unauthorized if user.blank?

          tel_params = params(user_telephone: [:raw_number, :number])
          number = tel_params[:raw_number] || tel_params[:number]
          if initiate_telephone_verification(user, number, auto_accept_confirmations: true)
            redirect_to(edit_sign_app_settings_telephones_registration_path(ri: params[:ri]))
          else
            render :new, status: :unprocessable_content
          end
        end

        def destroy
          telephone = current_client.client_telephones.find_by!(public_id: params(:id))
          authorize!(telephone)

          unless AuthMethodGuard.can_remove_telephone?(current_client, telephone)
            redirect_to(
              sign_app_settings_telephones_path,
              alert: t("sign.app.settings.telephone.destroy.last_method"),
            )
            return
          end

          telephone.destroy!
          create_audit_event!(ClientChronicleEvent::TELEPHONE_REMOVED, subject: telephone)

          redirect_to(
            sign_app_settings_telephones_path,
            notice: t("sign.app.settings.telephone.destroy.success"),
            status: :see_other,
          )
        end

        private

        def authorize_telephones!
          authorize!(ClientTelephone, to: :index?)
        end

        def authorize_telephone_registration!
          authorize!(ClientTelephone, to: :create?)
        end

        def create_audit_event!(event_id, subject:)
          ChronicleRecord.connected_to(role: :writing) do
            ClientChronicleEvent.find_or_create_by!(id: event_id)
            ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
          end

          ClientChronicle.create!(
            actor_type: "Client",
            actor_id: current_client.id,
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
          "settings_telephone"
        end
      end
    end
  end
end
