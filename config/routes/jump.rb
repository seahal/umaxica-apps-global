# typed: false
# frozen_string_literal: true

scope module: :jump, as: :jump do
  def exact_host_constraint(*hosts)
    /\A(?:#{hosts.map { |host| Regexp.escape(host) }.join("|")})\z/
  end

  jump_app_host = exact_host_constraint(
    ENV.fetch("JUMP_APP_URL", "jump.app.localhost"),
    ENV.fetch("JUMP_SERVICE_URL", "jump.app.localhost"),
    "jump.app.localhost",
  )
  jump_com_host = exact_host_constraint(
    ENV.fetch("JUMP_COM_URL", "jump.com.localhost"),
    ENV.fetch("JUMP_CORPORATE_URL", "jump.com.localhost"),
    "jump.com.localhost",
  )
  jump_org_host = exact_host_constraint(
    ENV.fetch("JUMP_ORG_URL", "jump.org.localhost"),
    ENV.fetch("JUMP_STAFF_URL", "jump.org.localhost"),
    "jump.org.localhost",
  )

  constraints host: jump_app_host do
    scope module: :app, as: :app do
      root to: "roots#index"
      # Health
      resource :health, only: :show
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  constraints host: jump_com_host do
    scope module: :com, as: :com do
      root to: "roots#index"
      # Health
      resource :health, only: :show
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  constraints host: jump_org_host do
    scope module: :org, as: :org do
      root to: "roots#index"
      # Health
      resource :health, only: :show
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end
end
