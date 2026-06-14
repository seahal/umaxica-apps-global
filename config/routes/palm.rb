# typed: false
# frozen_string_literal: true

scope module: :palm, as: :palm do
  # Application native API surface
  constraints host: ENV["PALM_SERVICE_URL"] do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :robot, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      namespace :api do
        namespace :v0 do
          resource :profile, only: :show
        end
      end
      # Reserved native callback compatibility stubs only. Palm is not an
      # OAuth/OIDC endpoint owner; Acme owns token issuance and native-device
      # transport belongs under API namespaces when implemented.
      namespace :oauth do
        resource :callback, only: :show
        get "callback/ios", to: "callbacks#show", as: :ios_callback
        get "callback/android", to: "callbacks#show", as: :android_callback
      end
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end
end
