# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require "bundler/setup"
require "debug"
require "rails"
require "minitest/autorun"
require "minitest/spec"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "exclusive-arc"

def tmp_dir
  File.expand_path("../tmp", __dir__)
end

FileUtils.rm_f Dir.glob("#{tmp_dir}/**/*")

require "active_model/railtie"
require "active_record/railtie"
require "action_text/engine"

require "config/application"
Rails.initialize!

require_relative "support/database"
