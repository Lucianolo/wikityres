class AddFinishedToQuery < ActiveRecord::Migration
  def change
    add_column :queries, :finished, :boolean
  end
end
