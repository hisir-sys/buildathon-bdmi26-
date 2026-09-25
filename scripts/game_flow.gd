extends RefCounted
# Tiny hand-off between scenes. main_room.gd fills this in when the game
# ends; ending_screen.gd reads it. Access it through a preload:
#   const GameFlow = preload("res://scripts/game_flow.gd")

# 1 = timer out, diamond left   (TOTAL FAILURE)
# 2 = timer out, diamond taken  (THE GREED TRAP)
# 3 = tasks done, diamond left  (MISSION ACCOMPLISHED)
# 4 = tasks done, diamond taken (THE SHADOW VICTORY)
static var ending_id: int = 1
static var tasks_done: int = 0
static var tasks_total: int = 5
static var seconds_left: int = 0
static var diamond_taken: bool = false
