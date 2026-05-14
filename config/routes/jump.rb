# typed: false
# frozen_string_literal: true

jump_hosts =
  lambda do |env_key, fallback, *local_aliases|
    hosts = [ENV.fetch(env_key, fallback)]
    hosts.concat(local_aliases) unless Rails.env.production?
    hosts.compact.uniq
  end

scope module: :jump, as: :jump do
  constraints host: jump_hosts.call("JUMP_CORPORATE_URL", "jump.com.localhost", "com.localhost") do
    scope module: :com, as: :com do
      root to: "roots#index"
      # Health
      resource :health, only: :show, controller: "health"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  constraints host: jump_hosts.call("JUMP_SERVICE_URL", "jump.app.localhost", "app.localhost") do
    scope module: :app, as: :app do
      root to: "roots#index"
      # Health
      resource :health, only: :show, controller: "health"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  constraints host: jump_hosts.call("JUMP_STAFF_URL", "jump.org.localhost", "org.localhost") do
    scope module: :org, as: :org do
      root to: "roots#index"
      # Health
      resource :health, only: :show, controller: "health"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end
end
