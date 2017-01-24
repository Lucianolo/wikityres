class AddPrezzoFinaleToPneumatico < ActiveRecord::Migration
  def change
    add_column :pneumaticos, :prezzo_finale, :float
  end
end
