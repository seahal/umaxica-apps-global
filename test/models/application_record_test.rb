# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  test "clear_fixed_id_seed_cache! clears the cache" do
    ApplicationRecord.clear_fixed_id_seed_cache!
    ApplicationRecord.insert_missing_fixed_ids!([99_999])
    assert_nothing_raised do
      ApplicationRecord.clear_fixed_id_seed_cache!
    end
  end

  test "insert_missing_fixed_ids! creates records for missing IDs" do
    ApplicationRecord.clear_fixed_id_seed_cache!
    max_id = ClientStatus.maximum(:id) || 0
    missing_id = max_id + 10_000

    assert_not_predicate ClientStatus.where(id: missing_id), :exists?

    assert_nothing_raised do
      ClientStatus.insert_missing_fixed_ids!([missing_id])
    end

    assert_predicate ClientStatus.where(id: missing_id), :exists?
  end

  test "insert_missing_fixed_ids! is idempotent" do
    ApplicationRecord.clear_fixed_id_seed_cache!
    max_id = ClientStatus.maximum(:id) || 0
    missing_id = max_id + 10_001

    ClientStatus.insert_missing_fixed_ids!([missing_id])
    count = ClientStatus.where(id: missing_id).count

    ClientStatus.insert_missing_fixed_ids!([missing_id])

    assert_equal count, ClientStatus.where(id: missing_id).count
  end

  test "insert_missing_fixed_ids! handles blank ids" do
    assert_nothing_raised do
      ApplicationRecord.insert_missing_fixed_ids!([])
    end
  end

  test "insert_missing_fixed_ids! handles nil ids" do
    assert_nothing_raised do
      ApplicationRecord.insert_missing_fixed_ids!(nil)
    end
  end
end
