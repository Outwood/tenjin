# frozen_string_literal: true

source "https://rubygems.org"

ruby "~> 3.4.9"

# Sets environment variables
gem "dotenv", groups: [:development, :test]
gem "recipient_interceptor"

gem "csv"

gem "rails", "~> 7.2.0", ">= 7.2.3.1"
gem "image_processing", "~> 2.1"

# Backend for the :mini_magick variant processor set in application.rb.
# Active Storage requires it directly and declares no dependency on it.
# The 4.x cap lives here because image_processing 2 made the backend a soft
# dependency and stopped supplying one; Active Storage 7.2 targets MiniMagick 4.
gem "mini_magick", "~> 4.12"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", ">= 1.1.0", require: false

gem "pg", ">= 0.18", "< 2.0"
gem "puma", "~> 8.0"
gem "rack"
gem "rack-cors", "~> 3"
gem "rack-session"
gem "rack-timeout", groups: [:production]

gem "delayed_job_active_record"

gem "aws-sdk-s3", "~> 1"
gem "aws-sdk-rails", "~> 5"

# The :ses ActionMailer delivery method, which aws-sdk-rails no longer carries
gem "aws-actionmailer-ses", "~> 1"

# HTTP for lib/wonderment, this app's Wonde API client
gem "faraday", "~> 2.14"

# Templates
gem "slim"
gem "jbuilder", "~> 2.5"
gem "high_voltage", "~> 5.0"

# Assets
gem "shakapacker", "= 10.3.2"

# Turbo (Hotwire)
gem "turbo-rails"

# User authentication
gem "devise", "~> 5.0"
gem "devise_invitable"
gem "omniauth"
gem "omniauth-oauth2"
gem "omniauth-wonde", "~> 0.2"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"

# User authorization
gem "pundit"
gem "rolify"

# Form builder
gem "simple_form"

# Pagination
gem "pagy", "~> 9.3"

# Bootstrap for emails
gem "bootstrap-email"
gem "sass-embedded", "~> 1"
gem "css_parser", "~> 3.1"

# Dyno scaling
gem "hirefire-resource"

# Metrics
gem "scout_apm"
gem "barnes"

group :development, :test do
  gem "rspec-rails"

  gem "ffaker"
  gem "factory_bot_rails"

  # Stub and expect HTTP requests
  gem "webmock"

  # Create a fake API
  gem "vcr"

  # Linting
  gem "slim_lint"
  gem "standard"
end

group :development do
  gem "listen", "~> 3.3"

  # Debugging
  gem "web-console", ">= 3.3.0"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Log messages sent to/from server
  gem "httplog"

  # Hunt for n+1
  gem "bullet"

  # Security scanning
  gem "brakeman", require: false
  gem "bundler-audit", require: false
end

group :test do
  gem "capybara"
  gem "cuprite", require: "capybara/cuprite"
  gem "shoulda-matchers", "~> 8.0"

  gem "simplecov", require: false
  gem "rspec_junit_formatter"

  # Readable RSpec diffs
  gem "super_diff"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]
