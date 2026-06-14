# typed: false
# frozen_string_literal: true

scope module: :core, as: :core do
  # Application BFF surface
  constraints host: [ENV["CORE_SERVICE_URL"], "jp.umaxica.app", "core.app.localhost"].compact do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
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

      namespace :api do
        namespace :v0 do
          resource :session, only: :show
          post "token/refresh", to: "tokens#refresh"
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

  # Corporate BFF surface
  constraints host: [ENV["CORE_CORPORATE_URL"], "core.com.localhost"].compact do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
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

      namespace :api do
        namespace :v0 do
          resource :session, only: :show
          post "token/refresh", to: "tokens#refresh"
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

  # Staff BFF surface
  constraints host: [ENV["CORE_STAFF_URL"], "core.org.localhost"].compact do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
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

      namespace :api do
        namespace :v0 do
          resource :session, only: :show
          post "token/refresh", to: "tokens#refresh"
        end
      end

      namespace :auth do
        resource :callback, only: :show
      end

      namespace :sso do
        # FIXME: remove :controller. I thought non- sense.
        resource :authorization, only: :show, path: "authorize"
        resource :logout, only: :create
      end

      resources :accounts, only: [:index]
    end
  end

  constraints host: [ENV["CORE_NETWORK_URL"], "core.net.localhost"].compact do
    scope module: :net, as: :network do
      root to: "roots#index"
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  constraints host: [ENV["CORE_DEVELOPER_URL"], "core.dev.localhost"].compact do
    scope module: :dev, as: :developer do
      root to: "roots#index"
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end
end
