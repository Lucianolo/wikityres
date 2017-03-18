HireFire::Resource.configure do |config|
  config.dyno(:all_worker) do
    HireFire::Macro::Delayed::Job.queue(mapper: :active_record)
  end
end