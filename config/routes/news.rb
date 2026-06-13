# typed: false
# frozen_string_literal: true

scope module: :news, as: :news do
  news_app_hosts = [ENV["NEWS_SERVICE_URL"], "news.app.localhost"].compact
  news_app_hosts.uniq!
  news_com_hosts = [ENV["NEWS_CORPORATE_URL"], "news.com.localhost"].compact
  news_com_hosts.uniq!
  news_org_hosts = [ENV["NEWS_STAFF_URL"], "news.org.localhost"].compact
  news_org_hosts.uniq!

  constraints ->(request) { news_app_hosts.include?(request.host) } do
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

  constraints ->(request) { news_com_hosts.include?(request.host) } do
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

  constraints ->(request) { news_org_hosts.include?(request.host) } do
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
