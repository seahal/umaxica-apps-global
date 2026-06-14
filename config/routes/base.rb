# typed: false
# frozen_string_literal: true

scope module: :base, as: :base do
  # Application control-plane surface
  constraints host: ENV["BASE_SERVICE_URL"] do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :robot, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  # Corporate control-plane surface
  constraints host: ENV["BASE_CORPORATE_URL"] do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :robot, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  # Staff control-plane surface
  constraints host: ENV["BASE_STAFF_URL"] do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :robot, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end
end
