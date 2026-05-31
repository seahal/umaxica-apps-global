# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
test_pgoptions =
  "-c max_parallel_workers=0 -c max_parallel_workers_per_gather=0 " \
  "-c max_parallel_maintenance_workers=0 -c jit=off"
ENV["PGOPTIONS"] = [ENV["PGOPTIONS"], test_pgoptions].compact.join(" ")

require_relative "../config/environment"
require "rails/test_help"

module TestPostgreSQLColumnDefinitions
  # The local PostgreSQL container has a very small shared-memory mount. Rails'
  # default metadata query joins comment/collation catalogs and can request a
  # 32MB dynamic shared-memory segment before any test runs.
  def column_definitions(table_name)
    query_rows(<<~SQL.squish)
      SELECT a.attname, format_type(a.atttypid, a.atttypmod),
             pg_get_expr(d.adbin, d.adrelid), a.attnotnull, a.atttypid, a.atttypmod,
             NULL::name AS collname, NULL::text AS comment,
             #{supports_identity_columns? ? "attidentity" : quote("")} AS identity,
             #{supports_virtual_columns? ? "attgenerated" : quote("")} AS attgenerated
        FROM pg_attribute a
        LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
       WHERE a.attrelid = #{quote(quote_table_name(table_name))}::regclass
         AND a.attnum > 0 AND NOT a.attisdropped
       ORDER BY a.attnum
    SQL
  end
end

ActiveSupport.on_load(:active_record_postgresqladapter) { prepend TestPostgreSQLColumnDefinitions }
ActiveRecord.verify_foreign_keys_for_fixtures = true

module ActiveSupport
  class TestCase
    # Run tests in parallel using Rails' standard process-based test runner.
    parallel_workers = Integer(ENV.fetch("PARALLEL_WORKERS", "1"))
    parallelize(workers: parallel_workers)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all
  end
end
