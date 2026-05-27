# frozen_string_literal: true

instance_eval(Rails.root.join("config/routes/core.rb").read, Rails.root.join("config/routes/core.rb").to_s)
