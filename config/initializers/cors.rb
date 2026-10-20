# Be sure to restart your server when you modify this file.

# The React front (Vite dev server) calls this API from another origin.
# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173")

    resource "/api/*",
      headers: :any,
      methods: [ :get, :post, :options, :head ]
  end
end
