# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      # Redirect shim: all read actions forward to base/app/identity/secrets/*.
      # Write actions return 410 Gone; the actual CRUD lives at base/app/identity/secrets.
      class SecretCredentialsController < ::Auth::App::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!

        def index = redirect_to(base_app_identity_secrets_path(ri: params[:ri]), status: :see_other)

        def show = redirect_to(base_app_identity_secret_path(params.expect(:id), ri: params[:ri]), status: :see_other)

        def new = redirect_to(new_base_app_identity_secret_path(ri: params[:ri]), status: :see_other)

        def edit
          redirect_to(
            edit_base_app_identity_secret_path(params.expect(:id), ri: params[:ri]),
            status: :see_other,
          )
        end

        def create = head(:gone)

        def update = head(:gone)

        def destroy = head(:gone)
      end
    end
  end
end
