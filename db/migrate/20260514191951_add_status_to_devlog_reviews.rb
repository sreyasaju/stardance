class AddStatusToDevlogReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :devlog_reviews, :status, :string
  end
end
