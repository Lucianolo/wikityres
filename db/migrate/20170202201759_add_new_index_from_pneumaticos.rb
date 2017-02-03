class AddNewIndexFromPneumaticos < ActiveRecord::Migration
  def change
    add_index :pneumaticos, :modello
  end
end
