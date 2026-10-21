class ReferenceRent < ApplicationRecord
  enum :construction_period, {
    before_1946: "before_1946",
    from_1946_to_1970: "1946_1970",
    from_1971_to_1990: "1971_1990",
    after_1990: "after_1990"
  }, validate: true

  validates :year, :district_id, :district_name, :zone_id, presence: true
  validates :rooms, inclusion: { in: 1..4 }
  validates :furnished, inclusion: { in: [ true, false ] }
  validates :min_per_sqm, :ref_per_sqm, :max_per_sqm, numericality: { greater_than: 0 }
  validate :rent_bounds_are_ordered

  def self.current_year
    maximum(:year)
  end

  private

  def rent_bounds_are_ordered
    return if [ min_per_sqm, ref_per_sqm, max_per_sqm ].any?(&:nil?)
    return if min_per_sqm <= ref_per_sqm && ref_per_sqm <= max_per_sqm

    errors.add(:base, "rents must satisfy min <= ref <= max")
  end
end
