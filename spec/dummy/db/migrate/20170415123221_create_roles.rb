class CreateRoles < ActiveRecord::Migration[5.0]
  def change
    create_table :roles do |t|
      t.belongs_to :user, index: true, null: false
      t.string :role, null: false
      t.timestamps null: false
    end
  end
end
