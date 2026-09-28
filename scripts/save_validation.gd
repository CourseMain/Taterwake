extends RefCounted

static func number(value: Variant, low: float, high: float, whole: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high and (not whole or float(value) == floor(float(value)))
