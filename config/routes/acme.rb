# typed: false
# frozen_string_literal: true

def exact_host_constraint(*hosts)
  normalized_hosts = hosts.filter_map { |host| normalize_route_host(host) }
  /\A(?:#{normalized_hosts.map { |host| Regexp.escape(host) }.join("|")})\z/
end

def normalize_route_host(host)
  host.to_s.strip.sub(/\Ahttps?:\/\//, "").split("/").first.presence
end

acme_app_host = exact_host_constraint(
  ENV.fetch("ACME_SERVICE_URL", "app.localhost"), "app.localhost",
  "www.app.localhost",
)
acme_com_host = exact_host_constraint(
  ENV.fetch("ACME_CORPORATE_URL", "com.localhost"), "com.localhost",
  "www.com.localhost",
)
acme_org_host = exact_host_constraint(
  ENV.fetch("ACME_STAFF_URL", "org.localhost"), "org.localhost",
  "www.org.localhost",
)

scope module: :acme, as: :acme do
  constraints host: acme_app_host do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      # Health
      resource :health, only: :show
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      # Public web API: cookie consent, theme
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end
      # Edge API
      namespace :edge do
        namespace :v0 do
          resource :health, only: :show
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      if Rails.env.local?
        # TODO: Remove these temporary R18 smoke-test routes after R18 gate rollout is verified.
        namespace :__dev, module: :dev, path: "__dev" do
          namespace :r18 do
            resource :gate, only: %i(show create) do
              get :blocked
              get :stopped
            end
            resource :open, only: %i(show create), controller: "open_smokes"
            resource :private, only: %i(show create), controller: "private"
          end
        end
      end
      namespace :sso do
        resource :authorization, only: :show, path: "authorize"
        resource :logout, only: :create
      end
      # for account page
      resources :accounts, only: [:index]
    end
  end

  constraints host: acme_com_host do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      # Health
      resource :health, only: :show
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      # Public web API: cookie consent, theme
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end
      # Edge API
      namespace :edge do
        namespace :v0 do
          resource :health, only: :show
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      namespace :sso do
        resource :authorization, only: :show, path: "authorize"
        resource :logout, only: :create
      end
      # for account page
      resources :accounts, only: [:index]
    end
  end

  constraints host: acme_org_host do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      # Health
      resource :health, only: :show
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      # Public web API: cookie consent, theme
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end
      # Edge API
      namespace :edge do
        namespace :v0 do
          resource :health, only: :show
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      namespace :sso do
        resource :authorization, only: :show, path: "authorize"
        resource :logout, only: :create
      end
      # for account page
      resources :accounts, only: [:index]
    end
  end

  constraints host: ENV["ACME_NETWORK_URL"] do
    scope module: :net, as: :network do
      root to: "roots#index", as: :root
      # Health
      resource :health, only: :show
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  constraints host: ENV["ACME_DEVELOPER_URL"] do
    scope module: :dev, as: :developer do
      root to: "roots#index", as: :root
      # Health
      resource :health, only: :show
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      # to show the jobs page
      mount MissionControl::Jobs::Engine, at: "/jobs"
      # to show the rails db page
      mount RailsDb::Engine, at: "/db"
    end
  end
end
