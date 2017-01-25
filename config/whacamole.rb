

# you can specify which dynos to watch for each app (default: `web`):
Whacamole.configure("wikityres") do |config|
  config.api_token = "5681181a-1f63-4619-b3fd-832be797e7ca" # you could also paste your token in here as a string
  config.dynos = %w{web worker}
  config.restart_threshold = 600 # in megabytes. default is 1000 (good for 2X dynos)
  config.restart_window = 30*60 # restart rate limit in seconds. default is 30 mins.
end