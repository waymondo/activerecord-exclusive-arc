class Dummy < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.paths["config/database"] = ["test/config/database.yml"]
  config.paths["db/migrate"] = ["tmp/db/migrate"]
end
