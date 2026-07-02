class AddTeenCreatorUrlToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :teen_creator_url, :string
  end
end
