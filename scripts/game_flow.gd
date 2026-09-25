extends RefCounted
# Tiny hand-off between scenes. main_room.gd fills this in when the game
# ends; ending_screen.gd reads it. Access it through a preload:
#   const GameFlow = preload("res://scripts/game_flow.gd")

# 1 = cleaning incomplete and spy assets not secured (MISSION FAILED)
# 2 = cleaning complete but spy objective failed / operation compromised
# 3 = cleaning complete, required spy assets secured, and player was not caught
static var ending_id: int = 1
static var tasks_done: int = 0
static var tasks_total: int = 9
static var seconds_left: int = 0
static var diamond_taken: bool = false
