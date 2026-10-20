# Shapes a RentComparison::Result as the public JSON contract.
#
# Kept apart from the service so the API format can change (or get a v2) without touching
# business logic. Amounts are sent as numbers: Rails would otherwise encode BigDecimal as
# strings ("975.0") to avoid precision loss; with 2 decimals a JS number is precise enough.
class RentComparisonSerializer
  def initialize(result)
    @result = result
  end

  def as_json(*)
    reference = @result.reference_rent

    {
      status: @result.status,
      year: @result.year,
      district: { id: reference.district_id, name: reference.district_name, zone_id: reference.zone_id },
      profile: {
        rooms: reference.rooms,
        construction_period: reference.construction_period,
        furnished: reference.furnished
      },
      surface: @result.surface.to_f,
      rent: @result.rent.to_f,
      rent_per_sqm: @result.rent_per_sqm.to_f,
      legal_rents: {
        min: @result.min_rent.to_f,
        ref: @result.ref_rent.to_f,
        max: @result.max_rent.to_f
      },
      per_sqm: {
        min: reference.min_per_sqm.to_f,
        ref: reference.ref_per_sqm.to_f,
        max: reference.max_per_sqm.to_f
      },
      excess: @result.excess.to_f
    }
  end
end
