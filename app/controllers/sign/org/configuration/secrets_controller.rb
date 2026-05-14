# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class SecretsController < ApplicationController
        auth_required!

        include ::Verification::Operator

        before_action :authenticate_operator!
        before_action :set_secret, only: %i(show edit update destroy)

        def index
          @secrets = current_operator.staff_secrets.order(created_at: :desc)
        end

        def show
        end

        def new
          @secret = current_operator.staff_secrets.new
          @raw_secret = OperatorSecret.generate_raw_secret
          session[:staff_secret_raw] = @raw_secret
          @secret.name = @raw_secret.first(4)
        end

        def edit
        end

        def create
          raw_secret = session.delete(:staff_secret_raw)
          OperatorSecrets::Create.call(
            actor: current_operator,
            staff: current_operator,
            params: secret_params,
            raw_secret: raw_secret,
          )

          flash[:notice] = t(".created")
          redirect_to(sign_org_configuration_secrets_path)
        rescue ActiveRecord::RecordInvalid => e
          @secret = e.record
          @raw_secret = raw_secret.presence || OperatorSecret.generate_raw_secret
          session[:staff_secret_raw] = @raw_secret
          render :new, status: :unprocessable_content
        end

        def update
          OperatorSecrets::Update.call(
            actor: current_operator,
            secret: @secret,
            params: secret_params,
          )

          flash[:notice] = t(".updated")
          redirect_to(sign_org_configuration_secrets_path)
        rescue ActiveRecord::RecordInvalid => e
          @secret = e.record.is_a?(OperatorSecret) ? e.record : @secret
          render :edit, status: :unprocessable_content
        end

        def destroy
          OperatorSecrets::Destroy.call(actor: current_operator, secret: @secret)
          flash[:notice] = t(".destroyed")
          redirect_to(sign_org_configuration_secrets_path, status: :see_other)
        end

        private

        def set_secret
          @secret = current_operator.staff_secrets.find_by!(public_id: params.expect(:id))
        end

        def secret_params
          params.fetch(:staff_secret, {}).permit(:name, :enabled)
        end

        def verification_required_action?
          %w(create update destroy).include?(action_name)
        end

        def verification_scope
          "configuration_secret"
        end
      end
    end
  end
end
