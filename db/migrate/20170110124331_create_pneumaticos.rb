class CreatePneumaticos < ActiveRecord::Migration
  def change
    create_table :pneumaticos do |t|
      t.string :marca
      t.string :modello
      t.string :fornitore
      t.string :nome_fornitore
      t.string :misura
      t.string :raggio
      t.string :stagione
      t.string :cod_vel
      t.float :prezzo_netto
      t.integer :giacenza

      t.timestamps null: false
    end
  end
end
