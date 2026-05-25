# typed: false
# frozen_string_literal: true

require "test_helper"

class RoutesPublicIdParamTest < ActiveSupport::TestCase
  test "routes do not use param public_id" do
    route_files = Rails.root.glob("{config/routes,config/routing}/*.rb")
    violations =
      route_files.filter_map do |file|
        next unless file.read.match?(/param:\s*:public_id/)

        file.relative_path_from(Rails.root).to_s
      end

    assert_empty violations, "Remove `param: :public_id` from route files: #{violations.join(", ")}"
  end
end
