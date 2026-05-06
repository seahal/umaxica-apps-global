# typed: false
# frozen_string_literal: true

Rails.application.routes.draw do
  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end
  # #FIXME remove or exile this
  # CSP violation reporting endpoint (host-agnostic, all domains)
  post "/csp-violation-report", to: "csp_violations#create"

  # BFF
  draw :apex
  # sign in / up
  draw :sign
  # Jump Page
  draw :jump

  root "inertia_example#index"
  get "inertia-example", to: "inertia_example#index"
end
