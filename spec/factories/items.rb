FactoryBot.define do
  factory :item do
    name { "Sample Item" }
    description { "This is a sample item description." }
    price { 19.99 }
    stock { 100 }
    category { "Sample Category" }
  end
end