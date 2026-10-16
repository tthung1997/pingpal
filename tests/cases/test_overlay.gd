extends TestCase


func test_polygon_covers_rects_and_nothing_else() -> void:
	var rects: Array[Rect2] = [Rect2(100, 200, 50, 80), Rect2(400, 150, 100, 130)]
	var polygon: PackedVector2Array = OverlayWindow.build_polygon(rects, Vector2(800, 300), 1.0)
	check(polygon.size() >= 3, "a usable polygon")
	check(Geometry2D.is_point_in_polygon(Vector2(120, 250), polygon), "inside the first rect is clickable")
	check(Geometry2D.is_point_in_polygon(Vector2(450, 200), polygon), "inside the second rect is clickable")
	check(not Geometry2D.is_point_in_polygon(Vector2(250, 250), polygon), "the gap between rects passes clicks through")
	check(not Geometry2D.is_point_in_polygon(Vector2(120, 100), polygon), "above a rect passes clicks through")
	check(not Geometry2D.is_point_in_polygon(Vector2(700, 280), polygon), "empty space passes clicks through")


func test_overlapping_rects_form_one_clickable_area() -> void:
	var rects: Array[Rect2] = [Rect2(100, 100, 100, 50), Rect2(130, 140, 40, 100)]
	var polygon: PackedVector2Array = OverlayWindow.build_polygon(rects, Vector2(400, 300), 1.0)
	check(Geometry2D.is_point_in_polygon(Vector2(110, 120), polygon), "wide top rect")
	check(Geometry2D.is_point_in_polygon(Vector2(150, 220), polygon), "tall rect below it")


func test_polygon_scales_to_physical_pixels() -> void:
	var rects: Array[Rect2] = [Rect2(10, 10, 20, 20)]
	var polygon: PackedVector2Array = OverlayWindow.build_polygon(rects, Vector2(200, 100), 2.0)
	check(Geometry2D.is_point_in_polygon(Vector2(30, 30), polygon), "logical (15,15) is physical (30,30)")
	check(not Geometry2D.is_point_in_polygon(Vector2(15, 15), polygon), "unscaled coordinates are outside")


func test_no_rects_never_yields_an_empty_polygon() -> void:
	var polygon: PackedVector2Array = OverlayWindow.build_polygon([], Vector2(800, 300), 1.0)
	eq(polygon.size(), 3, "an empty polygon would disable passthrough, so a 1px triangle is used")
