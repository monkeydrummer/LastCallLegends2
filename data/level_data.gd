class_name LevelData
extends Resource

## Unique id for saves / analytics.
@export var id: String = ""

@export var display_name: String = ""

## If non-empty, one texture is chosen at random when the run starts.
@export var background_pool: Array[Texture2D] = []

## Used when background_pool is empty.
@export var background_texture: Texture2D

## Seconds before a customer leaves (front of queue).
@export var wait_time_seconds: float = 28.0

## Level ends when this many seconds have elapsed.
@export var level_duration_seconds: float = 45.0

## Reserved for themed customer pools later.
@export var customer_theme_tag: String = ""
