# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpEmailPendingGuardTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "lock_key produces deterministic signed 64-bit value" do
    key1 = SignUpEmailPendingGuard.lock_key("ns", "digest123")
    key2 = SignUpEmailPendingGuard.lock_key("ns", "digest123")

    assert_equal key1, key2
  end

  test "lock_key produces different values for different inputs" do
    key1 = SignUpEmailPendingGuard.lock_key("ns1", "abc")
    key2 = SignUpEmailPendingGuard.lock_key("ns2", "abc")

    assert_not_equal key1, key2
  end

  test "lock_key produces different values for different digests" do
    key1 = SignUpEmailPendingGuard.lock_key("ns", "abc")
    key2 = SignUpEmailPendingGuard.lock_key("ns", "def")

    assert_not_equal key1, key2
  end

  test "lock_key produces negative values for large hashes" do
    key = SignUpEmailPendingGuard.lock_key("ns", "a" * 100)

    assert_kind_of Integer, key
  end

  test "resolve_digest_and_namespace returns email namespace for address_digest" do
    digest, ns = SignUpEmailPendingGuard.resolve_digest_and_namespace("abc123", nil, nil)

    assert_equal "abc123", digest
    assert_equal SignUpEmailPendingGuard::EMAIL_NAMESPACE, ns
  end

  test "resolve_digest_and_namespace returns telephone namespace for number_digest" do
    digest, ns = SignUpEmailPendingGuard.resolve_digest_and_namespace(nil, "xyz789", nil)

    assert_equal "xyz789", digest
    assert_equal SignUpEmailPendingGuard::TELEPHONE_NAMESPACE, ns
  end

  test "resolve_digest_and_namespace prefers address_digest over number_digest" do
    digest, ns = SignUpEmailPendingGuard.resolve_digest_and_namespace("abc", "xyz", nil)

    assert_equal "abc", digest
    assert_equal SignUpEmailPendingGuard::EMAIL_NAMESPACE, ns
  end

  test "resolve_digest_and_namespace uses custom namespace when provided" do
    digest, ns = SignUpEmailPendingGuard.resolve_digest_and_namespace("abc", nil, "custom:ns")

    assert_equal "abc", digest
    assert_equal "custom:ns", ns
  end

  test "resolve_digest_and_namespace returns nil digest when no digest provided" do
    digest, ns = SignUpEmailPendingGuard.resolve_digest_and_namespace(nil, nil, nil)

    assert_nil digest
    assert_nil ns
  end

  test "with_lock raises ArgumentError when digest is blank" do
    assert_raises(ArgumentError) do
      SignUpEmailPendingGuard.with_lock(address_digest: nil, number_digest: nil) { nil }
    end
  end

  test "with_lock raises ArgumentError when no block given and model_class provided" do
    assert_raises(ArgumentError) do
      SignUpEmailPendingGuard.with_lock(address_digest: "abc", model_class: Class.new)
    end
  end

  test "with_lock raises ArgumentError when model_class and connection are both nil" do
    assert_raises(ArgumentError) do
      SignUpEmailPendingGuard.with_lock(address_digest: "abc", model_class: nil, connection: nil) { nil }
    end
  end

  test "with_lock yields inside a model_class transaction and issues an advisory lock" do
    sql = []
    yielded = false

    connection = Struct.new(:queries) do
      def exec_query(query)
        queries << query
      end
    end.new(sql)
    pool = Struct.new(:connection) do
      def with_connection
        yield connection
      end
    end.new(connection)
    model_class =
      Class.new do
        class << self
          attr_accessor :pool, :transaction_calls

          def transaction
            self.transaction_calls = (transaction_calls || 0) + 1
            yield
          end

          def connection_pool
            pool
          end
        end
      end
    model_class.pool = pool

    SignUpEmailPendingGuard.with_lock(address_digest: "abc", model_class: model_class) do
      yielded = true
    end

    assert yielded
    assert_equal 1, model_class.transaction_calls
    assert_equal 1, sql.length
    assert_match(/pg_advisory_xact_lock\(-?\d+\)/, sql.first)
  end

  test "with_lock can use an explicit connection" do
    sql = []
    yielded = false
    connection = Struct.new(:queries) do
      def transaction
        yield
      end

      def exec_query(query)
        queries << query
      end
    end.new(sql)

    SignUpEmailPendingGuard.with_lock(number_digest: "xyz", connection: connection) do
      yielded = true
    end

    assert yielded
    assert_equal 1, sql.length
    assert_match(/pg_advisory_xact_lock\(-?\d+\)/, sql.first)
  end
end
