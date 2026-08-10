# frozen_string_literal: true

require "test_helper"

class DevelopmentContainerContractTest < ActiveSupport::TestCase
  REPOSITORY_ROOT = Rails.root
  CONFIGURATION_FILES = %w(compose.yaml compose.custom.yaml .devcontainer/compose.override.yml).freeze

  test "repository uses Containerfile build definitions exclusively" do
    dockerfiles = `git ls-files '*Dockerfile*'`.lines.map(&:strip).reject(&:empty?)

    assert_empty dockerfiles, "repository-owned Dockerfiles: #{dockerfiles.join(", ")}"
    assert_predicate REPOSITORY_ROOT.join("Containerfile"), :file?
  end

  test "local secrets are excluded from Git and both build contexts" do
    assert system("git", "check-ignore", "--quiet", ".secrets/contract-probe")

    %w(.containerignore .dockerignore).each do |path|
      patterns = REPOSITORY_ROOT.join(path).read.lines.map(&:strip)

      assert_includes patterns, ".secrets/", "#{path} must exclude .secrets/"
    end
  end

  test "compose configuration excludes forbidden host and privilege shortcuts" do
    configuration = CONFIGURATION_FILES.filter_map do |path|
      file = REPOSITORY_ROOT.join(path)
      file.read if file.exist?
    end.join("\n")

    forbidden = {
      "host credential mount" => %r{source:\s*["']?\$\{HOME[^\n]*(?:\.ssh|\.gnupg|\.config/(?:gh|opencode)|\.claude|\.codex|\.gitconfig)},
      "SSH agent forwarding" => /SSH_AUTH_SOCK/,
      "container engine socket" => %r{(?:docker|podman)\.sock},
      "privileged mode" => /^\s*privileged:\s*true\s*$/,
      "host networking" => /^\s*network_mode:\s*host\s*$/,
      "explicit tmpfs" => /^\s*tmpfs:/,
      "explicit shared memory size" => /^\s*shm_size:/,
    }

    forbidden.each do |description, pattern|
      assert_no_match pattern, configuration, description
    end
  end

  test "Containerfiles do not declare or copy credentials" do
    containerfiles = Dir.glob(REPOSITORY_ROOT.join("**/Containerfile"))
    credential_name = /(?:PASSWORD|SECRET|TOKEN|API_KEY|PRIVATE_KEY|AUTH_SOCK)/i

    containerfiles.each do |path|
      contents = File.read(path)

      assert_not contents.lines.any? { |line| line.match?(/^\s*(?:ARG|ENV)\s+.*#{credential_name}/) }, path
      assert_no_match(/^\s*COPY\s+.*(?:\.secrets|\.ssh|\.gnupg|\.config\/(?:gh|opencode)|\.claude|\.codex)/i, contents, path)
    end
  end

  test "supported devcontainer launcher selects the Podman-native compose provider" do
    launcher = REPOSITORY_ROOT.join("podman/tools/dcup").read

    assert_includes launcher, "--docker-path"
    assert_includes launcher, "/usr/bin/podman"
    assert_not_includes launcher, "CONTAINER_ENGINE:-"
    assert_includes launcher, "PODMAN_COMPOSE_PROVIDER"
    assert_includes launcher, "--docker-compose-path"
    assert_includes launcher, ".State.Running"
    assert_includes launcher, "rm --force --ignore global-devcontainer-core"
    assert_includes launcher, "/usr/bin/podman-compose"
    assert_not_includes launcher, "PODMAN_COMPOSE_PROVIDER:-"
    assert_includes launcher, "bin/setup-dev-secrets"

    devcontainer = REPOSITORY_ROOT.join(".devcontainer/devcontainer.json").read

    assert_includes devcontainer, "bin/setup-dev-secrets"
  end

  test "compose network external flags are booleans rather than interpolated strings" do
    compose_files = ["compose.yaml", "compose.custom.yaml", ".devcontainer/compose.override.yml"]

    compose_files.each do |relative_path|
      contents = REPOSITORY_ROOT.join(relative_path).read

      assert_no_match(/^\s*external:\s*["']?\$\{/i, contents, relative_path)
    end
  end

  test "PostgreSQL health checks authenticate through the runtime writer secret" do
    compose = REPOSITORY_ROOT.join("compose.yaml").read

    assert_operator compose.scan('export PGPASSWORD="$$(cat "$${POSTGRES_PASSWORD_FILE}")"').length,
                    :>=,
                    2
  end

  test "every mounted Compose secret is declared and provisioned by the setup script" do
    compose = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.yaml"), aliases: true)
    setup = REPOSITORY_ROOT.join("bin/setup-dev-secrets").read
    declared = compose.fetch("secrets").keys

    compose.fetch("services").each do |name, service|
      next unless service.is_a?(Hash)

      Array(service["secrets"]).each do |secret|
        assert_includes declared, secret, "service #{name} mounts an undeclared secret"
      end
    end

    declared.each do |secret|
      assert_includes setup, "[#{secret}]=", "bin/setup-dev-secrets does not provision #{secret}"
    end
  end

  test "RustFS credentials are mounted secrets rather than Compose interpolation" do
    compose = REPOSITORY_ROOT.join("compose.yaml").read

    assert_includes compose, "OBJECT_STORAGE_ACCESS_KEY_ID_FILE: /run/secrets/dev_rustfs_access_key"
    assert_includes compose, "OBJECT_STORAGE_SECRET_ACCESS_KEY_FILE: /run/secrets/dev_rustfs_secret_key"
    assert_no_match(
      /^\s*(?:OBJECT_STORAGE_(?:ACCESS_KEY_ID|SECRET_ACCESS_KEY)|RUSTFS_(?:ACCESS_KEY|SECRET_KEY|RPC_SECRET)):\s*["']?\$\{/,
      compose,
      "object-storage credentials must not come from .env interpolation",
    )
  end
end
