# Compares the rent a tenant pays with the legal bounds of the Paris rent control.
#
# Rents are "hors charges" (excluding service charges). Legally:
# - above the max ("loyer de référence majoré"), the rent is too high, unless the landlord
#   justifies a "complément de loyer";
# - below the min ("loyer de référence minoré"), the landlord may ask for an increase at renewal.
#
# A plain Ruby object with ActiveModel: typed attributes cast raw HTTP params ("42.5" -> BigDecimal)
# and validations give the controller ready-made error messages, without any database table.
class RentComparison
  include ActiveModel::Model
  include ActiveModel::Attributes

  # The dataset groups 4 rooms and more under 4
  MAX_ROOMS_IN_DATASET = 4

  Result = Data.define(
    :reference_rent, :year, :surface, :rent, :rent_per_sqm,
    :min_rent, :ref_rent, :max_rent, :status, :excess
  )

  attribute :district_id, :integer
  attribute :rooms, :integer
  attribute :construction_period, :string
  attribute :furnished, :boolean
  attribute :surface, :decimal
  attribute :rent, :decimal
  attribute :year, :integer

  validates :district_id, presence: true
  validates :rooms, numericality: { only_integer: true, greater_than: 0 }
  validates :construction_period, inclusion: { in: ReferenceRent.construction_periods.keys }
  validates :furnished, inclusion: { in: [ true, false ], message: "must be true or false" }
  validates :surface, numericality: { greater_than: 0, less_than: 1_000 }
  validates :rent, numericality: { greater_than: 0 }

  # Raises ActiveModel::ValidationError on invalid input (-> 422)
  # and ActiveRecord::RecordNotFound when no reference matches the profile (-> 404).
  def call
    validate!

    reference = ReferenceRent.find_by!(
      year: year || ReferenceRent.maximum(:year),
      district_id:,
      rooms: [ rooms, MAX_ROOMS_IN_DATASET ].min,
      construction_period:,
      furnished:
    )
    build_result(reference)
  end

  private

  def build_result(reference)
    min_rent = money(reference.min_per_sqm * surface)
    max_rent = money(reference.max_per_sqm * surface)

    Result.new(
      reference_rent: reference,
      year: reference.year,
      surface:,
      rent:,
      rent_per_sqm: money(rent / surface),
      min_rent:,
      ref_rent: money(reference.ref_per_sqm * surface),
      max_rent:,
      status: status_for(min_rent, max_rent),
      excess: [ rent - max_rent, 0 ].max
    )
  end

  # Bounds are inclusive: paying exactly the max is legal
  def status_for(min_rent, max_rent)
    if rent > max_rent then :above_max
    elsif rent < min_rent then :below_min
    else :within_range
    end
  end

  def money(amount)
    amount.round(2)
  end
end
