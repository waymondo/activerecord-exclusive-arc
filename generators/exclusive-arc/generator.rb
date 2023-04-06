require "rails/generators"
require "rails/generators/active_record/migration/migration_generator"

module ExclusiveArc
  class Generator < ActiveRecord::Generators::Base
    source_root File.expand_path("templates", __dir__)
    include Rails::Generators::Migration
  end
end
