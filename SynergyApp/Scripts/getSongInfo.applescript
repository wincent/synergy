-- getSongInfo.applescript
-- Synergy
-- Copyright 2002-present Greg Hurrell. All rights reserved.

tell application "iTunes"
	try
		-- this will fail if iTunes has no current selection
		set theTrack to get current track
	on error
		if player state is playing then
			return {"error"}
		else
			-- could be paused, stopped, fast forwarding, rewinding
			return {"not playing"}
		end if
	end try
	
	-- iTunes has a current selection, extract the info	
	if the class of current track is not URL track then
		return {player state:player state as string, current track:theTrack, name:name of theTrack, album:album of theTrack, artist:artist of theTrack, composer:composer of theTrack, time:time of theTrack, year:year of theTrack as Unicode text, rating:rating of theTrack as text, song repeat:song repeat of the container of theTrack as text, shuffle:shuffle of the container of theTrack as text, player position:player position}
	else
		-- for URL tracks, name = "current stream title" (usually includes track name and artist; artist = "name of current track" (usually the name of the radio station), player position = 0
		return {player state:player state as string, current track:theTrack, name:current stream title, album:"Streaming Internet Radio", artist:name of theTrack, composer:"", time:"", year:"", rating:rating of theTrack as text, song repeat:song repeat of the container of theTrack as text, shuffle:shuffle of the container of theTrack as text, player position:player position}
	end if
end tell
