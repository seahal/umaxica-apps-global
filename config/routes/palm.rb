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
      resource :robots, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  # Corporate native API surface
  constraints host: ENV["PALM_CORPORATE_URL"] do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :robots, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  # Staff native API surface
  constraints host: ENV["PALM_STAFF_URL"] do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :robots, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end
end
