# typed: false
# frozen_string_literal: true

require "test_helper"

class ParallelTestDatabaseClonerTest < ActiveSupport::TestCase
  ReplicaConfig =
    Struct.new(:name, :database, :replica, :configuration_hash, :schema_format) do
      def replica?
        replica
      end
    end

  test "creates a missing replica database from its base database" do
    base = ReplicaConfig.new("com_principal", "test_com_principal_db", false, {}, :sql)
    replica = ReplicaConfig.new("com_principal_replica", "test_com_principal_replica_db", true, {}, :sql)
    existing = Set.new([base.database])
    fingerprints = { base.database => "base-fingerprint" }
    schema_shas = { base.database => "schema-sha" }
    calls = []

    ParallelTestDatabaseCloner.stub(:database_fingerprint, ->(_config, database) { fingerprints.fetch(database) }) do
      ParallelTestDatabaseCloner.stub(
        :rebuild_clone,
        lambda do |_admin_connection, _config, source:, clone:, schema_sha:, clone_exists:|
          calls << [source, clone, schema_sha, clone_exists]
          existing.add(clone)
        end,
      ) do
        ParallelTestDatabaseCloner.ensure_replica_databases(
          Object.new,
          {},
          [base, replica],
          { "com_principal" => base },
          existing,
          fingerprints,
          schema_shas,
        )
      end
    end

    assert_equal [["test_com_principal_db", "test_com_principal_replica_db", "schema-sha", false]], calls
    assert_includes existing, replica.database
  end

  test "skips a replica database that already matches its base database" do
    base = ReplicaConfig.new("com_principal", "test_com_principal_db", false, {}, :sql)
    replica = ReplicaConfig.new("com_principal_replica", "test_com_principal_replica_db", true, {}, :sql)
    existing = Set.new([base.database, replica.database])
    fingerprints = {
      base.database => "base-fingerprint",
      replica.database => "base-fingerprint",
    }
    schema_shas = { base.database => "schema-sha" }

    ParallelTestDatabaseCloner.stub(:database_fingerprint, ->(_config, database) { fingerprints.fetch(database) }) do
      ParallelTestDatabaseCloner.stub(:rebuild_clone, ->(*) { flunk("expected no rebuild") }) do
        ParallelTestDatabaseCloner.ensure_replica_databases(
          Object.new,
          {},
          [base, replica],
          { "com_principal" => base },
          existing,
          fingerprints,
          schema_shas,
        )
      end
    end

    assert_includes existing, replica.database
  end
end
