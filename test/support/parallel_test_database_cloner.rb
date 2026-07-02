# frozen_string_literal: true

require "digest"
require "pg"
require "set"

module ParallelTestDatabaseCloner
  module_function

  def install!(workers:)
    return if workers <= 1

    ActiveSupport::Testing::Parallelization.before_fork_hook do
      rebuild_stale_worker_clones(workers)
    end
  end

  def rebuild_stale_worker_clones(workers)
    configs = ActiveRecord::Base.configurations.configs_for(env_name: "test", include_hidden: true)
    databases = configs.map(&:database).uniq.sort
    first_config = configs.first.configuration_hash
    schema_sha_by_database = configs.to_h { |config| [config.database, schema_sha(config)] }

    ActiveRecord::Base.connection_handler.clear_all_connections!

    admin_connection = connect(first_config, ENV.fetch("POSTGRESQL_DATABASE", "db"))
    existing = admin_connection.exec("select datname from pg_database").map { |row| row.fetch("datname") }.to_set

    missing_base = databases.reject { |database| existing.include?(database) }
    raise "Missing base test DBs: #{missing_base.join(', ')}. Run RAILS_ENV=test bin/rails db:test:prepare." unless missing_base.empty?

    base_fingerprint_by_database = databases.to_h { |database| [database, database_fingerprint(first_config, database)] }

    databases.each do |database|
      workers.times do |worker|
        clone = "#{database}_#{worker}"
        clone_exists = existing.include?(clone)
        next if clone_exists && database_fingerprint(first_config, clone) == base_fingerprint_by_database.fetch(database)

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
    tables = connection.exec(<<~SQL).map { |row| row.fetch("table_name") }.sort
      select schemaname || '.' || tablename as table_name
      from pg_tables
      where schemaname not in ('pg_catalog', 'information_schema')
    SQL
    migrations =
      if tables.include?("public.schema_migrations")
        connection.exec("select version from schema_migrations order by version").map { |row| row.fetch("version") }
      else
        []
      end
    metadata =
      if tables.include?("public.ar_internal_metadata")
        connection.exec(<<~SQL).map { |row| row.fetch("pair") }
          select key || '=' || value as pair
          from ar_internal_metadata
          where key <> 'schema_sha1'
          order by key
        SQL
      else
        []
      end

    Digest::SHA256.hexdigest(([tables, migrations, metadata].map { |items| items.join("\n") }).join("\n--\n"))
  ensure
    connection&.close
  end

  def set_schema_sha(config, database, schema_sha)
    return unless schema_sha

    connection = connect(config, database)
    table_exists = connection.exec("select to_regclass('public.ar_internal_metadata') is not null as present").first.fetch("present")
    return unless table_exists == "t"

    connection.exec_params(<<~SQL, [schema_sha])
      insert into ar_internal_metadata (key, value, created_at, updated_at)
      values ('schema_sha1', $1, current_timestamp, current_timestamp)
      on conflict (key) do update set value = excluded.value, updated_at = excluded.updated_at
    SQL
  ensure
    connection&.close
  end
end
