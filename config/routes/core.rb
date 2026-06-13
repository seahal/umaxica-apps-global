# typed: false
# frozen_string_literal: true

scope module: :core, as: :core do
  core_app_hosts = [ENV["CORE_SERVICE_URL"], "core.app.localhost"].compact
  core_app_hosts.uniq!
  core_com_hosts = [ENV["CORE_CORPORATE_URL"], "core.com.localhost"].compact
  core_com_hosts.uniq!
  core_org_hosts = [ENV["CORE_STAFF_URL"], "core.org.localhost"].compact
  core_org_hosts.uniq!

  constraints ->(request) { core_app_hosts.include?(request.host) } do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show, controller: "liveness"
        resource :readiness, only: :show, controller: "readiness"
        resource :startup, only: :show, controller: "startup"
      end
      resource :robots, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end

      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end

      namespace :auth do
        resource :callback, only: :show
      end

      namespace :sso do
        resource :authorization, only: :show, path: "authorize"
        resource :logout, only: :create
      end

      resources :accounts, only: [:index]
    end
  end

  constraints ->(request) { core_com_hosts.include?(request.host) } do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show, controller: "liveness"
        resource :readiness, only: :show, controller: "readiness"
        resource :startup, only: :show, controller: "startup"
      end
      resource :robots, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end

      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end

      namespace :auth do
        resource :callback, only: :show
      end

      namespace :sso do
        resource :authorization, only: :show, path: "authorize"
        resource :logout, only: :create
      end

      resources :accounts, only: [:index]
    end
  end

  constraints ->(request) { core_org_hosts.include?(request.host) } do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show, controller: "liveness"
        resource :readiness, only: :show, controller: "readiness"
        resource :startup, only: :show, controller: "startup"
      end
      resource :robots, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      resource :configuration, only: :show

      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end

      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end

      namespace :auth do
        resource :callback, only: :show
      end

      namespace :sso do
        resource :authorization, only: :show, path: "authorize"
        resource :logout, only: :create
      end

      resources :accounts, only: [:index]
    end
  end
end
