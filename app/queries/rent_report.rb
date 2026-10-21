# Rents are set per zone: every district of a zone shares the same values.
class RentReport
  include ActiveModel::Model
  include ActiveModel::Attributes

  FILTERS = %i[rooms construction_period furnished].freeze

  AVERAGES = {
    avg_min_per_sqm: "ROUND(AVG(min_per_sqm), 2)",
    avg_ref_per_sqm: "ROUND(AVG(ref_per_sqm), 2)",
    avg_max_per_sqm: "ROUND(AVG(max_per_sqm), 2)"
  }.freeze

  attribute :year, :integer
  attribute :rooms, :integer
  attribute :construction_period, :string
  attribute :furnished, StrictBoolean.new

  validates :rooms, numericality: { only_integer: true, in: 1..4 }, allow_nil: true
  validates :construction_period, inclusion: { in: ReferenceRent.construction_periods.keys }, allow_nil: true
  validates :furnished, inclusion: { in: [ true, false ], message: "must be true or false" }, allow_nil: true

  def by_district
    validate!

    rows(
      filtered.group(:district_id, :district_name, :zone_id).order(by_average_desc, :district_name),
      district_id: "district_id",
      district_name: "district_name",
      zone_id: "zone_id"
    )
  end

  def by_zone
    validate!

    rows(
      filtered.group(:zone_id).order(by_average_desc, :zone_id),
      zone_id: "zone_id",
      districts_count: "COUNT(DISTINCT district_id)",
      district_names: "ARRAY_AGG(DISTINCT district_name ORDER BY district_name)"
    )
  end

  def filters
    attributes.symbolize_keys.slice(*FILTERS).compact
  end

  private

  def filtered
    ReferenceRent.where(year:, **filters)
  end

  def by_average_desc
    Arel.sql("AVG(ref_per_sqm) DESC")
  end

  def rows(relation, columns)
    selects = columns.merge(AVERAGES)

    relation.pluck(*selects.values.map { Arel.sql(it) }).map do |values|
      selects.keys.zip(values).to_h.transform_values { it.is_a?(BigDecimal) ? it.to_f : it }
    end
  end
end
