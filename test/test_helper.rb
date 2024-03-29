ENV["RAILS_ENV"] ||= "test"

require "bundler/setup"

require "debug"
require "minitest/autorun"
require "minitest/spec"
require "active_support"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "activerecord-exclusive-arc"

require "active_model/railtie"
require "active_record/railtie"

require "config/application"
Rails.initialize!

require_relative "support/database"
