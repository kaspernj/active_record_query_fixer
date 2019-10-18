FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "email#{n}@example.com" }
    encrypted_password { "password" }
  end
end
