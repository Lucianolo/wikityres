class ChangeQueryNameToSearch < ActiveRecord::Migration
  def self.up
    rename_table :queries, :searchs
  end

  def self.down
    rename_table :searchs, :queries
  end
end
