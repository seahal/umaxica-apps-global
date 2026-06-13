# typed: false
# frozen_string_literal: true

scope module: :docs, as: :docs do
  docs_app_hosts = [ENV["DOCS_SERVICE_URL"], "docs.app.localhost"].compact
  docs_app_hosts.uniq!
  docs_com_hosts = [ENV["DOCS_CORPORATE_URL"], "docs.com.localhost"].compact
  docs_com_hosts.uniq!
  docs_org_hosts = [ENV["DOCS_STAFF_URL"], "docs.org.localhost"].compact
  docs_org_hosts.uniq!

  constraints ->(request) { docs_app_hosts.include?(request.host) } do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show, controller: "liveness"
        resource :readiness, only: :show, controller: "readiness"
        resource :startup, only: :show, controller: "startup"
      end
      resource :robots, only: :show, path: "robots.txt"
      resources :entries, only: %i(index show), param: :slug
      namespace :edge do
        namespace :v0 do
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end

  constraints ->(request) { docs_com_hosts.include?(request.host) } do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show, controller: "liveness"
        resource :readiness, only: :show, controller: "readiness"
        resource :startup, only: :show, controller: "startup"
      end
      resource :robots, only: :show, path: "robots.txt"
      resources :entries, only: %i(index show), param: :slug
      namespace :edge do
        namespace :v0 do
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end

  constraints ->(request) { docs_org_hosts.include?(request.host) } do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show, controller: "liveness"
        resource :readiness, only: :show, controller: "readiness"
        resource :startup, only: :show, controller: "startup"
      end
      resource :robots, only: :show, path: "robots.txt"
      resources :entries, only: %i(index show), param: :slug
      namespace :edge do
        namespace :v0 do
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end

end
