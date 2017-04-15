class Role < ApplicationRecord
  belongs_to :user

  validates :role, :user, presence: true
end
