function CoreMusicManager:check_music_switch()
  local switches = tweak_data.levels:get_music_switches()
  if switches and #switches > 0 then
	  Global.music_manager.current_track = switches[math.random(#switches)]
	  Global.music_manager.source:set_switch("music_randomizer", tostring(Global.music_manager.current_track))
  end
end

local _post_event = CoreMusicManager.post_event
function CoreMusicManager:post_event(name)
	_post_event(self, tostring(name))
end
