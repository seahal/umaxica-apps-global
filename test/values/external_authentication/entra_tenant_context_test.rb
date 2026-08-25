# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationEntraTenantContextTest < ActiveSupport::TestCase
  test "accepts UUID tenant and object identifiers" do
    context = ExternalAuthentication::EntraTenantContext.new(
      tenant_id: "11111111-1111-1111-1111-111111111111",
      object_identifier: "22222222-2222-2222-2222-222222222222",
    )

    assert_equal "11111111-1111-1111-1111-111111111111", context.tenant_id
    assert_equal "22222222-2222-2222-2222-222222222222", context.object_identifier
    assert_predicate context, :frozen?
  end

  test "rejects non-uuid tenant and object identifiers" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::EntraTenantContext.new(
        tenant_id: "not-a-uuid",
        object_identifier: "22222222-2222-2222-2222-222222222222",
      )
    end

    assert_raises(ArgumentError) do
      ExternalAuthentication::EntraTenantContext.new(
        tenant_id: "11111111-1111-1111-1111-111111111111",
        object_identifier: "bad",
      )
    end
  end
end
