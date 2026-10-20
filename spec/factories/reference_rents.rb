FactoryBot.define do
  factory :reference_rent do
    year { 2025 }
    sequence(:district_id) { |n| n }
    district_name { "Batignolles" }
    zone_id { 10 }
    rooms { 2 }
    construction_period { :before_1946 }
    furnished { false }
    min_per_sqm { 18.3 }
    ref_per_sqm { 26.1 }
    max_per_sqm { 31.3 }
  end
end
