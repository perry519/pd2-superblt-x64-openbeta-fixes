local _track_listen_start = MusicManager.track_listen_start

function MusicManager:track_listen_start(event, track)
    if track ~= nil then
        track = tostring(track) 
    end
	_track_listen_start(self, event, track)
end

function MusicManager:track_listen_stop()
    self._current_track = tostring(self._current_track)
    Global.music_manager.current_track = tostring(Global.music_manager.current_track)
    if self._current_event then
        Global.music_manager.source:post_event("stop_all_music")

        if Global.music_manager.current_event then
            Global.music_manager.source:post_event(Global.music_manager.current_event)
        end
    end

    if self._current_track and Global.music_manager.current_track then
        Global.music_manager.source:set_switch("music_randomizer", Global.music_manager.current_track)
    end

    self._current_event = nil
    self._current_track = nil
    self._skip_play = nil
end

function MusicManager:stop_listen_all()
    self._current_track = tostring(self._current_track)
    Global.music_manager.current_track = tostring(Global.music_manager.current_track)
    if self._current_music_ext or self._current_event then
        Global.music_manager.source:post_event("stop_all_music")
    end

    if self._current_music_ext and Global.music_manager.current_music_ext then
        Global.music_manager.source:post_event(Global.music_manager.current_music_ext)
    end

    if self._current_event and Global.music_manager.current_event then
        Global.music_manager.source:post_event(Global.music_manager.current_event)
    end

    if self._current_track and Global.music_manager.current_track then
        Global.music_manager.source:set_switch("music_randomizer", Global.music_manager.current_track)
    end

    self._current_music_ext = nil
    self._current_event = nil
    self._current_track = nil
    self._skip_play = nil
end
