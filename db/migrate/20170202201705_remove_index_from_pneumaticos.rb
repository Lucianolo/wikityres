class RemoveIndexFromPneumaticos < ActiveRecord::Migration
  def change
    remove_index :pneumaticos, :modello
  end
end
