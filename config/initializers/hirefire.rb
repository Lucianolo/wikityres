HireFire::Resource.configure do |config|
  config.dyno(:worker) do
    HireFire::Macro::Delayed::Job.queue(mapper: :active_record)
  end
end

#HireFire.configure do |config|
#  config.environment      = nil # default in production is :heroku. default in development is :noop
#  config.max_workers      = 4   # default is 1
#  config.min_workers      = 0   # default is 0
#  config.job_worker_ratio = [
#      { :jobs => 1,   :workers => 1 },
#      { :jobs => 2,  :workers => 2 },
#      { :jobs => 3,  :workers => 3 },
#      { :jobs => 4,  :workers => 4 }
#      
#    ]
#end