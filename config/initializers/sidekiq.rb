require "erb"
require "yaml"

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

redis_config = {
  url: redis_url,
  network_timeout: 5,
  pool_timeout: 5,
  size: Integer(ENV.fetch("REDIS_POOL_SIZE", ENV.fetch("SIDEKIQ_CONCURRENCY", "5"))) + 2
}

Sidekiq.configure_server do |config|
  config.redis = redis_config

  schedule_file = Rails.root.join("config", "schedule.yml")
  if File.exist?(schedule_file)
    Sidekiq::Cron::Job.load_from_hash(
      YAML.safe_load(ERB.new(File.read(schedule_file)).result, permitted_classes: [Symbol], aliases: true) || {}
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config.merge(
    size: Integer(ENV.fetch("REDIS_CLIENT_POOL_SIZE", "3"))
  )
end
