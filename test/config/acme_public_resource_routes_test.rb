# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmePublicResourceRoutesTest < ActiveSupport::TestCase
  test "accounts and organizations routes are index/show only" do
    route_file = Rails.root.join("config/routes/base.rb").read

    assert_match(/resources :accounts, only: %i\(index show\)/, route_file)
    assert_match(/resources :organizations, only: %i\(index show\)/, route_file)
    assert_no_match(/resources :accounts, only: %i\(index new create show edit update\)/, route_file)
    assert_no_match(/resources :organizations, only: %i\(index new create show edit update\)/, route_file)
  end

  test "route files do not use param public_id" do
    route_files = Rails.root.glob("config/routes/*.rb")
    violations =
      route_files.filter_map { |file|
        file.read.match?(/param:\s*:public_id/) ? file.relative_path_from(Rails.root).to_s : nil
      }

    assert_empty violations, "Remove `param: :public_id` from route files: #{violations.join(", ")}"
  end
end
