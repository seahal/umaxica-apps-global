# typed: false
# frozen_string_literal: true

scope module: :help, as: :help do
  help_app_hosts = [ENV["HELP_SERVICE_URL"], "help.app.localhost"].compact
  help_app_hosts.uniq!
  help_com_hosts = [ENV["HELP_CORPORATE_URL"], "help.com.localhost"].compact
  help_com_hosts.uniq!
  help_org_hosts = [ENV["HELP_STAFF_URL"], "help.org.localhost"].compact
  help_org_hosts.uniq!

  constraints ->(request) { help_app_hosts.include?(request.host) } do
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

  constraints ->(request) { help_com_hosts.include?(request.host) } do
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

  constraints ->(request) { help_org_hosts.include?(request.host) } do
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
