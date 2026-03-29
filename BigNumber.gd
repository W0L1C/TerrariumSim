## BigNumber.gd
## Scientific notation number that supports arbitrarily large values.
## Stores value as: mantissa × 10^exponent, where mantissa ∈ [1.0, 10.0)
## All operations return a new BigNumber; inputs are never mutated.
class_name BigNumber

const SUFFIXES: Array[String] = [
	"", "K", "M", "B", "T",
	"Qa", "Qi", "Sx", "Sp", "Oc", "No",
	"Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc",
	"Vi", "UVi", "DVi", "TVi", "QaVi", "QiVi", "SxVi", "SpVi", "OcVi", "NoVi",
	"Tg",
]

var mantissa: float = 0.0  ## Always in [1.0, 10.0) except when value is zero
var exponent: int = 0


func _init(m: float = 0.0, e: int = 0) -> void:
	mantissa = m
	exponent = e
	if mantissa != 0.0:
		_normalize()


# ── Constructors ──────────────────────────────────────────────────────────────

static func from_float(value: float) -> BigNumber:
	if value <= 0.0:
		return BigNumber.new(0.0, 0)
	# Use log10 to determine exponent, with epsilon to guard against fp rounding
	var log10_val: float = log(value) / log(10.0)
	var e: int = int(floor(log10_val + 1e-10))
	var m: float = value / pow(10.0, e)
	var result := BigNumber.new()
	result.mantissa = m
	result.exponent = e
	result._normalize()
	return result


static func from_int(value: int) -> BigNumber:
	if value <= 0:
		return BigNumber.new(0.0, 0)
	return BigNumber.from_float(float(value))


static func zero() -> BigNumber:
	return BigNumber.new(0.0, 0)


static func one() -> BigNumber:
	return BigNumber.new(1.0, 0)


static func from_save_dict(d: Dictionary) -> BigNumber:
	return BigNumber.new(float(d.get("m", 0.0)), int(d.get("e", 0)))


# ── Core helpers ──────────────────────────────────────────────────────────────

func copy() -> BigNumber:
	return BigNumber.new(mantissa, exponent)


func is_zero() -> bool:
	return mantissa <= 0.0


## Keep mantissa strictly in [1.0, 10.0)
func _normalize() -> void:
	if mantissa <= 0.0:
		mantissa = 0.0
		exponent = 0
		return
	while mantissa >= 10.0:
		mantissa /= 10.0
		exponent += 1
	while mantissa < 1.0:
		mantissa *= 10.0
		exponent -= 1


# ── Arithmetic ────────────────────────────────────────────────────────────────

func add(other: BigNumber) -> BigNumber:
	if is_zero():
		return other.copy()
	if other.is_zero():
		return copy()
	var diff: int = exponent - other.exponent
	# When exponents differ by > 17, the smaller number is below float precision
	if diff > 17:
		return copy()
	if diff < -17:
		return other.copy()
	var result := BigNumber.new()
	if diff >= 0:
		result.mantissa = mantissa + other.mantissa * pow(10.0, -diff)
		result.exponent = exponent
	else:
		result.mantissa = mantissa * pow(10.0, diff) + other.mantissa
		result.exponent = other.exponent
	result._normalize()
	return result


## Returns zero rather than negative — resources cannot go below zero
func subtract(other: BigNumber) -> BigNumber:
	if other.is_zero():
		return copy()
	var diff: int = exponent - other.exponent
	if diff > 17:
		return copy()
	if diff < -17:
		return BigNumber.zero()
	var result := BigNumber.new()
	if diff >= 0:
		result.mantissa = mantissa - other.mantissa * pow(10.0, -diff)
		result.exponent = exponent
	else:
		result.mantissa = mantissa * pow(10.0, diff) - other.mantissa
		result.exponent = other.exponent
	if result.mantissa <= 0.0:
		return BigNumber.zero()
	result._normalize()
	return result


func multiply(other: BigNumber) -> BigNumber:
	if is_zero() or other.is_zero():
		return BigNumber.zero()
	var result := BigNumber.new()
	result.mantissa = mantissa * other.mantissa
	result.exponent = exponent + other.exponent
	result._normalize()
	return result


## Multiply by a plain float — useful for delta time, multipliers, etc.
func multiply_float(factor: float) -> BigNumber:
	if is_zero() or factor <= 0.0:
		return BigNumber.zero()
	var result := BigNumber.new()
	result.mantissa = mantissa * factor
	result.exponent = exponent
	result._normalize()
	return result


func divide_float(divisor: float) -> BigNumber:
	if is_zero() or divisor <= 0.0:
		return BigNumber.zero()
	return multiply_float(1.0 / divisor)


# ── Comparison ────────────────────────────────────────────────────────────────

func greater_than(other: BigNumber) -> bool:
	if is_zero() and other.is_zero():
		return false
	if is_zero():
		return false
	if other.is_zero():
		return true
	if exponent != other.exponent:
		return exponent > other.exponent
	return mantissa > other.mantissa


func less_than(other: BigNumber) -> bool:
	return other.greater_than(self)


func greater_than_or_equal(other: BigNumber) -> bool:
	return not less_than(other)


# ── Conversion ────────────────────────────────────────────────────────────────

func to_float() -> float:
	return mantissa * pow(10.0, exponent)


## Human-readable display string: "1.23M", "45.6B", etc.
func to_display_string() -> String:
	if is_zero():
		return "0"

	# Handle negative exponents (fractional values, rare in idle games)
	if exponent < 0:
		return "%.4f" % to_float()

	var suffix_index: int = exponent / 3
	var remainder: int = exponent % 3
	var display_val: float = mantissa * pow(10.0, remainder)

	if suffix_index == 0:
		# Raw number: show up to 2 decimals for small values
		if display_val < 10.0:
			return "%.2f" % display_val
		elif display_val < 100.0:
			return "%.1f" % display_val
		else:
			return "%d" % int(display_val)

	if suffix_index < SUFFIXES.size():
		var suffix := SUFFIXES[suffix_index]
		if display_val >= 100.0:
			return "%d%s" % [int(display_val), suffix]
		elif display_val >= 10.0:
			return "%.1f%s" % [display_val, suffix]
		else:
			return "%.2f%s" % [display_val, suffix]

	# Beyond our suffix table — fall back to scientific notation
	return "%.3fe+%d" % [mantissa, exponent]


func to_save_dict() -> Dictionary:
	return {"m": mantissa, "e": exponent}
