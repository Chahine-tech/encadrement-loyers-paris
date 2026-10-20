# Average reference rent per district, computed by Postgres (GROUP BY), not in Ruby:
# one query returns 80 rows instead of loading thousands of records into memory.
class DistrictRentReport
  FILTERS = %i[rooms construction_period furnished].freeze

  def initialize(year:, filters: {})
    @year = year
    @filters = filters.to_h.symbolize_keys.slice(*FILTERS).compact_blank
  end

  def relation
    ReferenceRent
      .where(year: @year, **@filters)
      .group(:district_id, :district_name, :zone_id)
      .order(Arel.sql("AVG(ref_per_sqm) DESC"), :district_name)
  end

  def rows
    relation
      .pluck(:district_id, :district_name, :zone_id,
             Arel.sql("ROUND(AVG(min_per_sqm), 2)"),
             Arel.sql("ROUND(AVG(ref_per_sqm), 2)"),
             Arel.sql("ROUND(AVG(max_per_sqm), 2)"))
      .map do |id, name, zone_id, min, ref, max|
        { district_id: id, district_name: name, zone_id:,
          avg_min_per_sqm: min.to_f, avg_ref_per_sqm: ref.to_f, avg_max_per_sqm: max.to_f }
      end
  end
end
