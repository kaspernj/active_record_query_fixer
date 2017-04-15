class User < ApplicationRecord
  has_many :roles, dependent: :destroy

  validates :email, presence: true
end
