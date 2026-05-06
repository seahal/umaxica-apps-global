# typed: false
# frozen_string_literal: true

require Rails.root.join("lib/id_host_env").to_s

IdHostEnv.validate! if Rails.env.production?
