class ChangeColumnNamesOnMagazzino < ActiveRecord::Migration
  def change
    rename_column :magazzinos, :gruppo, :pneumatico
    rename_column :magazzinos, :pezzi, :pneumatici_disponibili
  end
end
