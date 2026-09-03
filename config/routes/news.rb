# typed: false
# frozen_string_literal: true

# News owns the public news content surface.
scope module: :news, as: :news do
  # App news host.
  constraints host: [ENV["PRIVATE_NEWS_SERVICE_URL"], "news.jp.umaxica.app", "news.app.localhost"].compact do
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

      # Public read-only news API.
      namespace :api do
        # Versioned news API.
        namespace :v0 do
          # Published news entries. `param: :slug` only renames the path
          # segment to the public identifier; the route stays fully resourceful.
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end

  # Corporate news host.
  constraints host: [ENV["PRIVATE_NEWS_CORPORATE_URL"], "news.jp.umaxica.com", "news.com.localhost"].compact do
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

      # Public read-only news API.
      namespace :api do
        # Versioned news API.
        namespace :v0 do
          # Published news entries. `param: :slug` only renames the path
          # segment to the public identifier; the route stays fully resourceful.
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end

  # Staff news host.
  constraints host: [ENV["PRIVATE_NEWS_STAFF_URL"], "news.jp.umaxica.org", "news.org.localhost"].compact do
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

      # Public read-only news API.
      namespace :api do
        # Versioned news API.
        namespace :v0 do
          # Published news entries. `param: :slug` only renames the path
          # segment to the public identifier; the route stays fully resourceful.
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end
end
