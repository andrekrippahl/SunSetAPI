Rails.application.config.to_prepare do
  Dir[Rails.root.join("app/errors/**/*.rb")].sort.each { |f| require_dependency f }
end
