class AddUserToMagazzinos < ActiveRecord::Migration
  def change
    add_reference :magazzinos, :user, index: true, foreign_key: true
  end
end
