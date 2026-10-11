extends RefCounted
## Stop the fixture's mixer work before freeing its game or quitting Godot.
static func release(game: Node, tree: SceneTree) -> bool:
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var playbacks: Array[WeakRef] = []
	for player: AudioStreamPlayer in game.find_children("*", "AudioStreamPlayer", true, false):
		if player.has_stream_playback(): playbacks.append(weakref(player.get_stream_playback()))
		player.stop()
		player.stream = null
	for frame in range(120):
		if playbacks.all(func(ref: WeakRef): return ref.get_ref() == null): break
		await tree.process_frame
	return playbacks.all(func(ref: WeakRef): return ref.get_ref() == null)
