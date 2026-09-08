# typed: false
# frozen_string_literal: true

# EID owns the dedicated Entity Identifier service boundary.
scope module: :eid, as: :eid do
  constraints host: [ENV["PUBLIC_EID_SERVICE_URL"], ENV["EID_SERVICE_URL"], ENV["PRIVATE_EID_SERVICE_URL"],
                     "eid.umaxica.net", "eid.net.localhost",].compact do
    scope module: :net, as: :net do
      root to: "roots#index"

      resource :revision, only: :show, format: false

      resource :health, only: :show, format: false
      namespace :health do
        resource :liveness, only: :show, format: false
        resource :readiness, only: :show, format: false
        resource :startup, only: :show, format: false
      end

      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      namespace :api do
        namespace :v0 do
          resources :resources, only: :show, param: :eid
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end
end
