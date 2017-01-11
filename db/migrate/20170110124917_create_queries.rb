class CreateQueries < ActiveRecord::Migration
  def change
    create_table :queries do |t|
      t.string :misura
      t.string :tag

      t.timestamps null: false
    end
  end
end
