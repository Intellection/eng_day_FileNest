class CreateUserFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :user_files do |t|
      t.references :user, null: false, foreign_key: true
      t.string :filename
      t.string :content_type
      t.integer :file_size
      t.datetime :uploaded_at

      t.timestamps
    end
  end
end
