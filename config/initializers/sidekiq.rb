# Sidekiq reads REDIS_URL by default; set explicitly so the dependency is visible.
redis_config = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

Sidekiq.configure_server { |config| config.redis = redis_config }
Sidekiq.configure_client { |config| config.redis = redis_config }
