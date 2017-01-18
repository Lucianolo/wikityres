class ChangeQueryNameToSearchs < ActiveRecord::Migration
  def self.up
    rename_table :searchs, :searches
  end

  def self.down
    rename_table :searches, :searchs
  end
end
