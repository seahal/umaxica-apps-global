# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcSubjectTest < ActiveSupport::TestCase
  test "uses prefixed public subject instead of database id" do
    client = clients(:one)

    assert_equal "cli_#{client.public_id}", OidcSubject.for(client, resource_type: "client")
    assert_equal client.public_id, OidcSubject.public_id_from("cli_#{client.public_id}", resource_type: "client")
  end

  test "uses separate prefixes for each actor type" do
    assert_equal "opr", OidcSubject.prefix_for("operator")
    assert_equal "vis", OidcSubject.prefix_for("visitor")
  end
end
