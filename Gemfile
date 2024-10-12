source "https://rubygems.org"

gem "debug"
gem "standard", "~> 1.26"

if (rails_version = ENV["RAILS_VERSION"])
  gem "rails", "~> #{rails_version}"
else
  gem "rails"
end

case ENV["DATABASE_ADAPTER"]
when "sqlite3"
  gem "sqlite3", "~> 2.1.0"
when "postgresql"
  gem "pg"
when "mysql2"
  gem "mysql2"
end

gemspec
