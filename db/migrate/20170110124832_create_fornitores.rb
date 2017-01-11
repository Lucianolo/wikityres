class CreateFornitores < ActiveRecord::Migration
  def change
    create_table :fornitores do |t|
      t.string :nome
      t.string :indirizzo
      t.string :user_name
      t.string :password
      t.string :status
      
      t.timestamps null: false
    end
  end
end
