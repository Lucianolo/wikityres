class AddQueryToPneumatico < ActiveRecord::Migration
  def change
    add_column :pneumaticos, :query, :string
  end
end
