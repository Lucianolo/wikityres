class AddStagioneToQueries < ActiveRecord::Migration
  def change
    add_column :queries, :stagione, :string
  end
end
