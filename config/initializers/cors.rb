Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow both hostnames you'll see in dev
    origins 'http://127.0.0.1:5173',
            'http://127.0.0.1:5174',
            'http://localhost:5173',
            'http://localhost:5174'

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization" ],
      max_age: 600
  end
end
