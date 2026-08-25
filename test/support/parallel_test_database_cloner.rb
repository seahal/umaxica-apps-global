# frozen_string_literal: true

require "digest"
require "fileutils"
require "pg"
require "set"

module ParallelTestDatabaseCloner
  # CREATE DATABASE ... TEMPLATE fails when the template is used by another
  # concurrent copy, so parallelism is across distinct template sources only.
  CLONE_THREADS = 8

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

  # Staleness is judged from the schema_sha comment stamped on each clone
  # database (readable for all clones in one pg_database catalog query), NOT
  # from per-clone data fingerprints: clones are dropped and re-templated on any
  # schema change, and test writes are rolled back by transactional fixtures, so
  # a per-clone data scan (previously: one connection + count(*) on every table
  # for each of workers x databases clones) bought no real protection for its
  # cost. If a clone is ever corrupted outside that model, drop it (or wipe the
  # tmpfs data dir) and it is rebuilt on the next run.
  def rebuild_stale_worker_clones(workers)
    configs = ActiveRecord::Base.configurations.configs_for(env_name: "test", include_hidden: true)
    base_configs = configs.reject(&:replica?)
    base_configs_by_name = base_configs.index_by(&:name)
    databases = configs.map(&:database).uniq.sort
    first_config = configs.first.configuration_hash
    schema_sha_by_database = base_configs.to_h { |config| [config.database, schema_sha(config)] }
    configs.select(&:replica?).each do |replica_config|
      base_config = base_configs_by_name.fetch(replica_config.name.delete_suffix("_replica"))
      schema_sha_by_database[replica_config.database] = schema_sha_by_database.fetch(base_config.database)
    end

    ActiveRecord::Base.connection_handler.clear_all_connections!

    admin_connection = connect(first_config, ENV.fetch("POSTGRESQL_DATABASE", "db"))
    admin_connection.exec("select pg_advisory_lock(hashtext('umaxica_parallel_test_database_cloner'))")

    stamped_sha = clone_sha_by_database(admin_connection)

    missing_base = base_configs.map(&:database).reject { |database| stamped_sha.key?(database) }
    # rubocop:disable I18n/RailsI18n/DecorateString
    raise RuntimeError,
          "Missing base test DBs: #{missing_base.join(", ")}. " \
          "Run RAILS_ENV=test bin/rails db:test:prepare." unless missing_base.empty?
    # rubocop:enable I18n/RailsI18n/DecorateString

    # Replica base DBs are themselves template clones of their writer DB and in
    # turn serve as templates for their own worker clones, so they must be
    # current before the worker-clone pass.
    replica_tasks =
      configs.select(&:replica?).filter_map do |replica_config|
        base_config = base_configs_by_name.fetch(replica_config.name.delete_suffix("_replica"))
        clone_task(
          stamped_sha,
          source: base_config.database,
          clone: replica_config.database,
          sha: schema_sha_by_database.fetch(replica_config.database),
        )
      end
    run_clone_tasks(first_config, replica_tasks)
    replica_tasks.each { |task| stamped_sha[task.fetch(:clone)] = task.fetch(:sha) }

    worker_tasks =
      databases.flat_map do |database|
        workers.times.filter_map do |worker|
          clone_task(
            stamped_sha,
            source: database,
            clone: "#{database}_#{worker}",
            sha: schema_sha_by_database.fetch(database),
          )
        end
      end
    run_clone_tasks(first_config, worker_tasks)
  ensure
    admin_connection&.exec("select pg_advisory_unlock(hashtext('umaxica_parallel_test_database_cloner'))")
    admin_connection&.close
  end

  # One catalog query yields existence + stamped schema sha for every database.
  def clone_sha_by_database(connection)
    connection.exec(<<~SQL.squish).to_h { |row| [row.fetch("datname"), row["sha"]] }
      select datname, shobj_description(oid, 'pg_database') as sha
      from pg_database
    SQL
  end

  def clone_task(stamped_sha, source:, clone:, sha:)
    # A nil sha (schema dump file absent) cannot prove freshness, so the clone
    # rebuilds every run until the dump exists.
    return nil if sha && stamped_sha.key?(clone) && stamped_sha[clone] == sha

    { source: source, clone: clone, sha: sha, clone_exists: stamped_sha.key?(clone) }
  end

  def run_clone_tasks(config, tasks)
    groups = tasks.group_by { |task| task.fetch(:source) }.values
    return if groups.empty?

    queue = Queue.new
    groups.each { |group| queue << group }
    thread_count = [CLONE_THREADS, groups.size].min
    thread_count.times { queue << nil }

    errors = Queue.new
    Array.new(thread_count) {
      Thread.new do # rubocop:disable ThreadSafety/NewThread
        connection = connect(config, ENV.fetch("POSTGRESQL_DATABASE", "db"))
        begin
          loop do
            group = queue.pop
            break if group.nil?

            group.each { |task| rebuild_clone(connection, **task) }
          end
        rescue => e
          errors << e
        ensure
          connection.close
        end
      end
    }.each(&:join)

    raise errors.pop unless errors.empty?
  end

  def rebuild_clone(admin_connection, source:, clone:, sha:, clone_exists:)
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
    return unless sha

    admin_connection.exec(
      "comment on database #{admin_connection.quote_ident(clone)} is '#{admin_connection.escape_string(sha)}'",
    )
  end

  def terminate_connections(connection, database)
    connection.exec_params(
      "select pg_terminate_backend(pid) from pg_stat_activity where datname = $1 and pid <> pg_backend_pid()",
      [database],
    )
  end

  def schema_sha(config)
    schema_path = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(config, config.schema_format)
    return nil unless File.exist?(schema_path)

    digest = Digest::SHA1.new
    digest << File.binread(schema_path)
    Array(config.migrations_paths).sort.each do |path|
      Dir.glob(File.join(path, "*.rb")).each do |migration_path|
        digest << migration_path
        digest << File.binread(migration_path)
      end
    end
    digest.hexdigest
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
end
