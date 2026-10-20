# Average reference rents grouped by district or by zone, computed by Postgres (GROUP BY),
# not in Ruby: one query returns a few dozen rows instead of loading thousands of records.
#
# In the dataset, rents are set per zone (14 zones), and the 80 districts of a zone share the
# same values. The zone report is therefore the meaningful one; the district report shows ties.
class RentReport
  FILTERS = %i[rooms construction_period furnished].freeze

  AVERAGES = {
    avg_min_per_sqm: "ROUND(AVG(min_per_sqm), 2)",
    avg_ref_per_sqm: "ROUND(AVG(ref_per_sqm), 2)",
    avg_max_per_sqm: "ROUND(AVG(max_per_sqm), 2)"
  }.freeze

  GROUPINGS = {
    district: {
      columns: { district_id: "district_id", district_name: "district_name", zone_id: "zone_id" },
      group: %i[district_id district_name zone_id],
      tie_breaker: :district_name
    },
    zone: {
      columns: {
        zone_id: "zone_id",
        districts_count: "COUNT(DISTINCT district_id)",
        district_names: "ARRAY_AGG(DISTINCT district_name ORDER BY district_name)"
      },
      group: %i[zone_id],
      tie_breaker: :zone_id
    }
  }.freeze

  def initialize(by:, year:, filters: {})
    @grouping = GROUPINGS.fetch(by)
    @year = year
    @filters = filters.to_h.symbolize_keys.slice(*FILTERS).compact_blank
  end

  def relation
    ReferenceRent
      .where(year: @year, **@filters)
      .group(*@grouping[:group])
      .order(Arel.sql("AVG(ref_per_sqm) DESC"), @grouping[:tie_breaker])
  end

  def rows
    selects = @grouping[:columns].merge(AVERAGES)

    relation.pluck(*selects.values.map { Arel.sql(it) }).map do |values|
      selects.keys.zip(values).to_h.transform_values { it.is_a?(BigDecimal) ? it.to_f : it }
    end
  end
end
