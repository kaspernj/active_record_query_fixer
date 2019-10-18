FactoryBot.define do
  factory :role do
    user
    role { "administrator" }
  end
end
