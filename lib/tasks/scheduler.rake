desc "This task is called by the Heroku scheduler add-on"
task :update => :environment do
  puts "Updating resources..."
  Pneumatico.update
  puts "done."
end

