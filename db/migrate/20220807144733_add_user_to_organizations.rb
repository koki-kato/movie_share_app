class AddUserToOrganizations < ActiveRecord::Migration[6.1]
  def change
    add_reference :organizations, :organization, null: false, foreign_key: true
  end
end