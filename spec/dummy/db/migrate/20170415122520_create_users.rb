class CreateUsers < ActiveRecord::Migration[5.0]
  def change
    create_table :users do |t|
      t.string :email, index: true, null: false
      t.string :encrypted_password, null: false
      t.timestamps null: false
    end
  end
end
