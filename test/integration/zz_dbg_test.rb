require "test_helper"
class ZzDbgTest < ActionDispatch::IntegrationTest
  test "dump" do
    h = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    ["/sign/up/email/new", "/sign/in/email/new"].each do |p|
      host! h
      get p
      follow_redirect! if response.redirect?
      puts "PATH #{p} COMPONENT #{inertia_component}"
      puts JSON.pretty_generate(inertia_props.except("chrome"))
    end
  end
end
