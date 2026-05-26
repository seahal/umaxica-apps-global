# typed: false
# frozen_string_literal: true

def core_exact_host_constraint(*hosts)
  /\A(?:#{hosts.map { |host| Regexp.escape(host) }.join("|")})\z/
end

core_app_host = core_exact_host_constraint(
  ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app"),
)
core_com_host = core_exact_host_constraint(
  ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com"),
)
core_org_host = core_exact_host_constraint(
  ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org"),
)

scope module: :core, as: :core do
  constraints host: core_app_host do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :health, only: :show
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
          resource :health, only: :show
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

  constraints host: core_com_host do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :health, only: :show
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
          resource :health, only: :show
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

  constraints host: core_org_host do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :health, only: :show
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
          resource :health, only: :show
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
