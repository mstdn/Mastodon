class CreateGlitchNotes < ActiveRecord::Migration[5.1]
  def change
    create_table :glitch_notes do |t|
      t.bigint :target_id, null: false
      t.string :target_type, null: false
      t.text :note, null: false
      t.index [:target_id, :target_type]
      t.timestamps
    end
  end
end
