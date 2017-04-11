class CreateMagazzinos < ActiveRecord::Migration
  def change
    create_table :magazzinos do |t|
      t.string :gruppo
      t.string :corda
      t.string :serie
      t.string :cerchio
      t.string :misura
      t.string :cod_carico
      t.string :cod_vel
      t.string :marca
      t.string :modello
      t.string :dot
      t.string :battistrada
      t.string :lotto
      t.string :shore
      t.string :targa
      t.string :cliente
      t.string :rete
      t.string :scaffale
      t.string :ubicazione
      t.string :pezzi
      t.string :stagione
      t.timestamps null: false
    end
  end
end
