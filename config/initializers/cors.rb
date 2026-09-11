# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

allowed_origins = ENV.fetch("FRONTEND_ORIGIN", "")
  .split(",")
  .map(&:strip)
  .reject(&:empty?)

unless Rails.env.production?
  allowed_origins << %r{\Ahttps://[a-z0-9\-]+\.vercel\.app\z}
end

if Rails.env.development?
  allowed_origins.concat(%w[http://localhost:3000 http://localhost:5147])
end

if allowed_origins.empty?
  Rails.logger.warn("[cors] No allowed origins configured. Set FRONTEND_ORIGIN or browser clients will be blocked.")
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"]
  end
end
