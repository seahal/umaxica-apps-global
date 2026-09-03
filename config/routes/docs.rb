# typed: false
# frozen_string_literal: true

# Docs owns the public documentation content surface.
scope module: :docs, as: :docs do
  # App documentation host.
  constraints host: [ENV["PRIVATE_DOCS_SERVICE_URL"], "docs.jp.umaxica.app", "docs.app.localhost"].compact do
    # App surface controllers.
    scope module: :app, as: :app do
      # Thin landing endpoint.
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show

      # Resourceful plain-text health endpoints.
      resource :health, only: :show, format: false do
        scope module: :health do
          resources :startups, only: :index, format: false
          resources :livenesses, only: :index, format: false
          resources :readinesses, only: :index, format: false
        end
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public read-only documentation API.
      namespace :api do
        # Versioned documentation API.
        namespace :v0 do
          # Published documentation entries. `param: :slug` only renames the path
          # segment to the public identifier; the route stays fully resourceful.
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end

  # Corporate documentation host.
  constraints host: [ENV["PRIVATE_DOCS_CORPORATE_URL"], "docs.jp.umaxica.com", "docs.com.localhost"].compact do
    # Corporate surface controllers.
    scope module: :com, as: :com do
      # Thin landing endpoint.
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show

      # Resourceful plain-text health endpoints.
      resource :health, only: :show, format: false do
        scope module: :health do
          resources :startups, only: :index, format: false
          resources :livenesses, only: :index, format: false
          resources :readinesses, only: :index, format: false
        end
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public read-only documentation API.
      namespace :api do
        # Versioned documentation API.
        namespace :v0 do
          # Published documentation entries.
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end

  # Staff documentation host.
  constraints host: [ENV["PRIVATE_DOCS_STAFF_URL"], "docs.jp.umaxica.org", "docs.org.localhost"].compact do
    # Staff surface controllers.
    scope module: :org, as: :org do
      # Thin landing endpoint.
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show

      # Resourceful plain-text health endpoints.
      resource :health, only: :show, format: false do
        scope module: :health do
          resources :startups, only: :index, format: false
          resources :livenesses, only: :index, format: false
          resources :readinesses, only: :index, format: false
        end
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public read-only documentation API.
      namespace :api do
        # Versioned documentation API.
        namespace :v0 do
          # Published documentation entries.
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end
end
