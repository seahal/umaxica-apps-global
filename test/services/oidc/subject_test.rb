# typed: false
# frozen_string_literal: true

require "test_helper"

class Oidc::SubjectTest < ActiveSupport::TestCase
  test "uses prefixed public subject instead of database id" do
    client = clients(:one)

    assert_equal "cli_#{client.public_id}", Oidc::Subject.for(client, resource_type: "client")
    assert_equal client.public_id, Oidc::Subject.public_id_from("cli_#{client.public_id}", resource_type: "client")
  end

  test "uses separate prefixes for each actor type" do
    assert_equal "opr", Oidc::Subject.prefix_for("operator")
    assert_equal "vis", Oidc::Subject.prefix_for("visitor")
  end
end
