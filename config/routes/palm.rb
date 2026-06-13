# typed: false
# frozen_string_literal: true

scope module: :palm, as: :palm do
  # FIXME: what is these lines?
  palm_app_hosts = [ENV["PALM_SERVICE_URL"], "palm.app.localhost"].compact
  palm_app_hosts.uniq!
  palm_com_hosts = [ENV["PALM_CORPORATE_URL"], "palm.com.localhost"].compact
  palm_com_hosts.uniq!
  palm_org_hosts = [ENV["PALM_STAFF_URL"], "palm.org.localhost"].compact
  palm_org_hosts.uniq!

  constraints ->(request) { palm_app_hosts.include?(request.host) } do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show, controller: "liveness"
        resource :readiness, only: :show, controller: "readiness"
        resource :startup, only: :show, controller: "startup"
      end
      resource :robots, only: :show, path: "robots.txt"
    end
  end

  constraints ->(request) { palm_com_hosts.include?(request.host) } do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show, controller: "liveness"
        resource :readiness, only: :show, controller: "readiness"
        resource :startup, only: :show, controller: "startup"
      end
      resource :robots, only: :show, path: "robots.txt"
    end
  end

  constraints ->(request) { palm_org_hosts.include?(request.host) } do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show, controller: "liveness"
        resource :readiness, only: :show, controller: "readiness"
        resource :startup, only: :show, controller: "startup"
      end
      resource :robots, only: :show, path: "robots.txt"
    end
  end
end
