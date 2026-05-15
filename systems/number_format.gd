extends Node

const SUFFIXES: Array[String] = [
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"
]
const SUFFIX_THRESHOLD: float = 1000.0
const DECIMALS: int = 1

func coins(value: float) -> String:
	if is_nan(value) or is_inf(value):
		return "0"
	var abs_value: float = abs(value)
	if abs_value < SUFFIX_THRESHOLD:
		return "%d" % int(value)
	var tier: int = int(floor(log(abs_value) / log(SUFFIX_THRESHOLD)))
	tier = clamp(tier, 0, SUFFIXES.size() - 1)
	var scaled: float = value / pow(SUFFIX_THRESHOLD, tier)
	return "%.*f%s" % [DECIMALS, scaled, SUFFIXES[tier]]
