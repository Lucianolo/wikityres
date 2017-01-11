class AddIndexToPneumatico < ActiveRecord::Migration
  def change
    add_index :pneumaticos, :modello, :unique => true
  end
end
