class_name BeerStylePalette
extends Resource

## One color per tap (index 0 = tap 1, … index 4 = tap 5).
@export var beer_colors: Array[Color] = [
	Color(0.35, 0.28, 0.18, 1.0),
	Color(0.92, 0.78, 0.35, 1.0),
	Color(0.25, 0.45, 0.75, 1.0),
	Color(0.85, 0.45, 0.15, 1.0),
	Color(0.55, 0.12, 0.12, 1.0),
]

func get_color_for_tap(tap_index: int) -> Color:
	var i: int = clampi(tap_index - 1, 0, beer_colors.size() - 1)
	return beer_colors[i]
