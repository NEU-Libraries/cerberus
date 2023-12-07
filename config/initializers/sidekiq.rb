# TODO: fix Derivatives::PdfJob.perform_async(@file_id, @work_id) to take native JSON type not Valkyrie::ID
Sidekiq.strict_args!(false)

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://redis:6379/0' }
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://redis:6379/0' }
end
