# typed: false
# frozen_string_literal: true

require Rails.root.join("lib/jit/id_host_env").to_s

Jit::IdHostEnv.validate! if Rails.env.production?
