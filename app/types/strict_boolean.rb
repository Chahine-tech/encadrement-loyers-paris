# The built-in :boolean type casts any unknown string to true ("maybe" -> true).
# This one keeps unknown values as they are, so an inclusion validation can reject them.
class StrictBoolean < ActiveModel::Type::Boolean
  private

  def cast_value(value)
    case value
    when true, "true", "1" then true
    when false, "false", "0" then false
    when "" then nil
    else value
    end
  end
end
