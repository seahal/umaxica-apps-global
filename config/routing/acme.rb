# frozen_string_literal: true

instance_eval(Rails.root.join("config/routes/acme.rb").read, Rails.root.join("config/routes/acme.rb").to_s)
