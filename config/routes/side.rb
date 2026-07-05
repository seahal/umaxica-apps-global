# typed: false
# frozen_string_literal: true

# Side owns the Rails control-plane surface.
scope module: :side, as: :side do
  # App control-plane host. Hosts listed declaratively (DRY intentionally broken).
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).side_service.host, "side.app.localhost"].compact do
    # App surface controllers.
    scope module: :app, as: :app do
      # Thin landing endpoint.
      root to: "roots#index"

      # Basic health summary.
      resource :health, only: :show

      # Machine-readable health probes.
      namespace :health do
        # Process liveness probe.
        resource :liveness, only: :show

        # Dependency readiness probe.
        resource :readiness, only: :show

        # Boot/startup probe.
        resource :startup, only: :show
      end

      # Crawler policy endpoint; keep fixed public path.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint; keep fixed public path.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # Control-plane settings index.
      resource :settings, only: :show

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Canonical browser sign-out flow.
      # FIXME: nasty entrypoint!
      resource :sign_out, only: %i(new edit create), path: "sign/out" do
        # FIXME: nasty entrypoint!
        resource :completion, only: :show, path: "complete", module: :sign_outs
      end

      # RP login start: redirects to Base /oauth/authorize.
      namespace :oidc do
        # FIXME: nasty entrypoint!
        resource :authorization, only: :show, to: "/side/app/auth/authorizations#show"
        # FIXME: nasty entrypoint!
        resource :callback, only: :show, to: "/side/app/auth/callbacks#show"
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  # Corporate control-plane host.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).side_corporate.host,
                     "side.com.localhost",].compact do
    # Corporate surface controllers.
    scope module: :com, as: :com do
      # Thin landing endpoint.
      root to: "roots#index"

      # Basic health summary.
      resource :health, only: :show

      # Machine-readable health probes.
      namespace :health do
        # Process liveness probe.
        resource :liveness, only: :show

        # Dependency readiness probe.
        resource :readiness, only: :show

        # Boot/startup probe.
        resource :startup, only: :show
      end

      # Crawler policy endpoint; keep fixed public path.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint; keep fixed public path.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # Control-plane settings index.
      resource :settings, only: :show

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Canonical browser sign-out flow.
      # FIXME: nasty entrypoint!
      resource :sign_out, only: %i(new edit create), path: "sign/out" do
        # FIXME: nasty entrypoint!
        resource :completion, only: :show, path: "complete", module: :sign_outs
      end

      # RP login start: redirects to Base /oauth/authorize.
      namespace :oidc do
        # FIXME: nasty entrypoint!
        resource :authorization, only: :show, to: "/side/com/auth/authorizations#show"
        # FIXME: nasty entrypoint!
        resource :callback, only: :show, to: "/side/com/auth/callbacks#show"
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  # Staff control-plane host.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).side_staff.host, "side.org.localhost"].compact do
    # Staff surface controllers.
    scope module: :org, as: :org do
      # Thin landing endpoint.
      root to: "roots#index"

      # Basic health summary.
      resource :health, only: :show

      # Machine-readable health probes.
      namespace :health do
        # Process liveness probe.
        resource :liveness, only: :show

        # Dependency readiness probe.
        resource :readiness, only: :show

        # Boot/startup probe.
        resource :startup, only: :show
      end

      # Crawler policy endpoint; keep fixed public path.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint; keep fixed public path.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # Control-plane settings index.
      resource :settings, only: :show

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Canonical browser sign-out flow.
      # FIXME: nasty entrypoint!
      resource :sign_out, only: %i(new edit create), path: "sign/out" do
        # FIXME: nasty entrypoint!
        resource :completion, only: :show, path: "complete", module: :sign_outs
      end

      # RP login start: redirects to Base /oauth/authorize.
      namespace :oidc do
        # FIXME: nasty entrypoint!
        resource :authorization, only: :show, to: "/side/org/auth/authorizations#show"
        # FIXME: nasty entrypoint!
        resource :callback, only: :show, to: "/side/org/auth/callbacks#show"
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end
end
