# typed: false
# frozen_string_literal: true

scope module: :base, as: :base do
  # FIXME: what is these lines?
  base_app_hosts = [ENV["BASE_SERVICE_URL"], "base.app.localhost"].compact
  base_app_hosts.uniq!
  base_com_hosts = [ENV["BASE_CORPORATE_URL"], "base.com.localhost"].compact
  base_com_hosts.uniq!
  base_org_hosts = [ENV["BASE_STAFF_URL"], "base.org.localhost"].compact
  base_org_hosts.uniq!

  constraints ->(request) { base_app_hosts.include?(request.host) } do
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

  constraints ->(request) { base_com_hosts.include?(request.host) } do
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

  constraints ->(request) { base_org_hosts.include?(request.host) } do
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
