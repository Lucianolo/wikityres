class AddPfuToPneumatico < ActiveRecord::Migration
  def change
    add_column :pneumaticos, :pfu, :string
  end
end
