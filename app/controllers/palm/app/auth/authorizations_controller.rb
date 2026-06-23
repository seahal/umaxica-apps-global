# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Auth
      class AuthorizationsController < Palm::App::BareController
        include ::OidcSsoInitiator

        AUTHENTICATION_MODE = :open

        def show
          return render plain: "Invalid client", status: :bad_request unless valid_client_id?

          url = initiate_oidc_session!(screen_hint: screen_hint_param)
          redirect_to(url, allow_other_host: true)
        end

        private

        def oidc_client_id
          client_id_param
        end

        def oidc_acme_host
          ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
        end

        def client_id_param
          params[:client_id].to_s
        end

        def valid_client_id?
          %w(app-ios-rp app-android-rp).include?(client_id_param)
        end

        def screen_hint_param
          return "signin" if params[:screen_hint].to_s == "signin"

          "signup"
        end
      end
    end
  end
end
