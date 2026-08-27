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

  test "devcontainer uses the standard CLI lifecycle without a repository launcher" do
    devcontainer = REPOSITORY_ROOT.join(".devcontainer/devcontainer.json").read

    assert_not_predicate REPOSITORY_ROOT.join("podman/tools/dcup"), :exist?
    assert_includes devcontainer, "bin/setup-dev-secrets"
    assert_not_includes devcontainer, "ensure-shared-networks"
  end

  test "devcontainer feature is the only Tailscale binary source" do
    devcontainer = REPOSITORY_ROOT.join(".devcontainer/devcontainer.json").read
    containerfile = REPOSITORY_ROOT.join("Containerfile").read
    supervisor = REPOSITORY_ROOT.join(".devcontainer/tailscale-core-supervisor.sh").read

    assert_includes devcontainer, "ghcr.io/devcontainer-community/devcontainer-features/tailscale.com:1"
    assert_no_match(/tailscale\/tailscale|tailscale-toolchain/, containerfile)
    assert_includes supervisor, "TAILSCALE_BIN=/usr/bin/tailscale"
    assert_includes supervisor, "TAILSCALED_BIN=/usr/sbin/tailscaled"
  end

  test "security scans include the Dev Container overlay while it is still loaded" do
    devcontainer = REPOSITORY_ROOT.join(".devcontainer/devcontainer.json").read

    assert_includes devcontainer, "./compose.override.yml"
    assert_includes CONFIGURATION_FILES, ".devcontainer/compose.override.yml"
  end

  test "compose network external flags are booleans rather than interpolated strings" do
    compose_files = ["compose.yaml", "compose.custom.yaml", ".devcontainer/compose.override.yml"]

    compose_files.each do |relative_path|
      contents = REPOSITORY_ROOT.join(relative_path).read

      assert_no_match(/^\s*external:\s*["']?\$\{/i, contents, relative_path)
    end
  end

  test "the tunnel connector joins only the Rails frontend network" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")
    connector_networks = connector.fetch("networks")

    assert_includes connector_networks, "frontend",
                    "a service-level networks: list in an overlay replaces the base list rather " \
                    "than merging with it, so removing frontend here silently detaches the " \
                    "connector from the private *.localhost Rails origins"
    assert_equal ["frontend"], connector_networks
    assert_not overlay.fetch("networks", {}).key?("edge-tunnel"),
               "Edge reaches Rails through Workers VPC; the repositories must not share a " \
               "host Podman network"
    assert_not connector.key?("extra_hosts"),
               "the connector reaches Rails over its private Podman network; a host-gateway " \
               "alias unnecessarily expands the origins reachable from the tunnel sidecar"
  end

  test "the tunnel connector can identify the tunnel it is asked to run" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")
    argv = connector.fetch("command").split

    assert_equal "${CLOUDFLARED_TOKEN:?CLOUDFLARED_TOKEN must be set in .env}",
                 connector.fetch("environment").fetch("TUNNEL_TOKEN")
    assert_equal "run", argv.last
    assert_includes argv, "run", "the connector must still run a tunnel"
  end

  test "the tunnel connector uses a supported pinned cloudflared release" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")

    assert_equal "docker.io/cloudflare/cloudflared:2026.8.2", connector.fetch("image")
  end

  test "no service restarts without a bound" do
    %w(compose.yaml compose.custom.yaml .devcontainer/compose.override.yml).each do |relative_path|
      compose = YAML.safe_load_file(REPOSITORY_ROOT.join(relative_path), aliases: true)

      compose.fetch("services", {}).each do |name, service|
        next unless service.is_a?(Hash) && service.key?("restart")

        assert_not_equal "unless-stopped", service.fetch("restart"),
                         "#{relative_path}: #{name} would restart forever with no Podman " \
                         "backoff, turning a startup misconfiguration into a restart storm"
      end
    end
  end

  test "the tunnel connector caps what a crash loop can consume" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")

    %w(cpus mem_limit pids_limit logging).each do |key|
      assert connector.key?(key),
             "cloudflare-tunnel declares no #{key}, so a crash loop is bounded only by the host"
    end

    assert_not connector.key?("profiles"),
               "the always-merged development overlay must start its authenticated connector " \
               "during the standard Dev Container lifecycle"
  end

  test "the tunnel token comes only from the gitignored repository environment file" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")
    services = overlay.fetch("services")

    assert system("git", "check-ignore", "--quiet", ".env")
    assert_not connector.key?("volumes")
    assert_not services.key?("cloudflared-login")
    assert_not services.key?("cloudflared-credentials")
    assert_not_includes overlay.fetch("volumes", {}).keys, "cloudflared-credentials"
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
