source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.5"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.0.10"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Redis adapter to run Action Cable in production
gem "redis", "~> 5.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# S3-compatible storage adapter (used for Cloudflare R2 and Supabase Storage)
gem "aws-sdk-s3", require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem "rack-cors"

gem "rack-attack", "~> 6.7"

# JSON serialization
gem "blueprinter"

# Pagination
gem "kaminari"

# LLM provider abstraction (used by OCR/AI infrastructure)
gem "ruby_llm"
gem "ruby_llm-schema"

# Messaging providers
gem "twilio-ruby", "~> 7.0"

# Authentication
gem "devise"
gem "devise-jwt"

# Sidekiq for background jobs
gem "sidekiq", "~> 7.0"

# Recurring job scheduling (config/schedule.yml)
gem "sidekiq-cron", "~> 1.12"

# PDF rendering (category receipts)
gem "prawn", "~> 2.5"
gem "prawn-table", "~> 0.2"

# Datadog APM
gem "datadog", "~> 2.0", require: false

# Pinned to avoid breaking Sidekiq 7.3.x (connection_pool 3.x changed `pop` signature
# and crashes the Sidekiq scheduler on boot). Remove when upgrading to Sidekiq 8.x.
gem "connection_pool", "~> 2.4"

# Environment variables
gem "dotenv-rails", groups: [:development, :test]

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"

  # Schema annotations on models
  gem "annotate"
end

