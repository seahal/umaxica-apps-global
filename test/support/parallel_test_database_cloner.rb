# frozen_string_literal: true

require "digest"
require "fileutils"
require "pg"
require "set"

module ParallelTestDatabaseCloner
  module_function

  def install!(workers:)
    acquire_test_process_lock!

    return if workers <= 1

    ActiveSupport::Testing::Parallelization.before_fork_hook do
      rebuild_stale_worker_clones(workers)
    end

    ActiveSupport::Testing::Parallelization.after_fork_hook do |worker|
      ActiveRecord::Base.configurations.configs_for(env_name: "test", include_hidden: true).each do |db_config|
        db_config._database = "#{db_config.database}_#{worker}"
      end
      ActiveRecord::Base.establish_connection
    end
  end

  def acquire_test_process_lock!
    return if @test_process_lock

    FileUtils.mkdir_p(Rails.root.join("tmp"))
    @test_process_lock = Rails.root.join("tmp/parallel-test-databases.lock").open(File::RDWR | File::CREAT, 0o644)
    @test_process_lock.flock(File::LOCK_EX)

    at_exit do
      @test_process_lock&.flock(File::LOCK_UN)
      @test_process_lock&.close
    end
  end

  def rebuild_stale_worker_clones(workers)
    configs = ActiveRecord::Base.configurations.configs_for(env_name: "test", include_hidden: true)
    databases = configs.map(&:database).uniq.sort
    first_config = configs.first.configuration_hash
    schema_sha_by_database = configs.to_h { |config| [config.database, schema_sha(config)] }

    ActiveRecord::Base.connection_handler.clear_all_connections!

    admin_connection = connect(first_config, ENV.fetch("POSTGRESQL_DATABASE", "db"))
    admin_connection.exec("select pg_advisory_lock(hashtext('umaxica_parallel_test_database_cloner'))")
    existing = admin_connection.exec("select datname from pg_database").map { |row| row.fetch("datname") }.to_set

    missing_base = databases.reject { |database| existing.include?(database) }
    raise "Missing base test DBs: #{missing_base.join(", ")}. Run RAILS_ENV=test bin/rails db:test:prepare." unless missing_base.empty?

    base_fingerprint_by_database =
      databases.index_with { |database|
        database_fingerprint(first_config, database)
      }

    databases.each do |database|
      workers.times do |worker|
        clone = "#{database}_#{worker}"
        clone_exists = existing.include?(clone)
        next if clone_exists && database_fingerprint(
          first_config,
          clone,
        ) == base_fingerprint_by_database.fetch(database)

        rebuild_clone(
          admin_connection,
          first_config,
          source: database,
          clone: clone,
          schema_sha: schema_sha_by_database.fetch(database),
          clone_exists: clone_exists,
        )
        existing.add(clone)
      end
    end
  ensure
    admin_connection&.exec("select pg_advisory_unlock(hashtext('umaxica_parallel_test_database_cloner'))")
    admin_connection&.close
  end

  def rebuild_clone(admin_connection, config, source:, clone:, schema_sha:, clone_exists:)
    if clone_exists
      terminate_connections(admin_connection, clone)

      begin
        admin_connection.exec("drop database #{admin_connection.quote_ident(clone)} with (force)")
      rescue PG::SyntaxError
        admin_connection.exec("drop database #{admin_connection.quote_ident(clone)}")
      end
    end

    admin_connection.exec(
      "create database #{admin_connection.quote_ident(clone)} template #{admin_connection.quote_ident(source)}",
    )
    set_schema_sha(config, clone, schema_sha)
  end

  def terminate_connections(connection, database)
    connection.exec_params(
      "select pg_terminate_backend(pid) from pg_stat_activity where datname = $1 and pid <> pg_backend_pid()",
      [database],
    )
  end

  def schema_sha(config)
    schema_path = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(config, config.schema_format)
    File.exist?(schema_path) ? Digest::SHA1.file(schema_path).hexdigest : nil
  end

  def connect(config, database)
    PG.connect(
      host: config.fetch(:host),
      port: config.fetch(:port, 5432),
      user: config.fetch(:username),
      password: config[:password],
      dbname: database,
    )
  end

  def database_fingerprint(config, database)
    connection = connect(config, database)
    tables = connection.exec(<<~SQL.squish).map { |row| row.fetch("table_name") }.sort
      select schemaname || '.' || tablename as table_name
      from pg_tables
      where schemaname not in ('pg_catalog', 'information_schema')
    SQL
    row_counts =
      tables.filter_map do |table|
        next if table == "public.ar_internal_metadata"

        quoted_table = table.split(".", 2).map { |part| connection.quote_ident(part) }.join(".")
        "#{table}=#{connection.exec("select count(*) as count from #{quoted_table}").first.fetch("count")}"
      end
    migrations =
      if tables.include?("public.schema_migrations")
        connection.exec("select version from schema_migrations order by version").map { |row| row.fetch("version") }
      else
        []
      end
    metadata =
      if tables.include?("public.ar_internal_metadata")
        connection.exec(<<~SQL.squish).map { |row| row.fetch("pair") }
          select key || '=' || value as pair
          from ar_internal_metadata
          where key <> 'schema_sha1'
          order by key
        SQL
      else
        []
      end

    Digest::SHA256.hexdigest(
      ([tables, row_counts, migrations, metadata].map { |items|
        items.join("\n")
      }).join("\n--\n"),
    )
  ensure
    connection&.close
  end

  def set_schema_sha(config, database, schema_sha)
    return unless schema_sha

    connection = connect(config, database)
    table_exists = connection.exec("select to_regclass('public.ar_internal_metadata') is not null as present").first.fetch("present")
    return unless table_exists == "t"

    connection.exec_params(<<~SQL.squish, [schema_sha])
      insert into ar_internal_metadata (key, value, created_at, updated_at)
      values ('schema_sha1', $1, current_timestamp, current_timestamp)
      on conflict (key) do update set value = excluded.value, updated_at = excluded.updated_at
    SQL
  ensure
    connection&.close
  end
end
