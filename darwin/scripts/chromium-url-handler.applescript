-- Receive macOS URL events and route them by Chromium's data directory,
-- rather than asking Launch Services to choose a running Chromium instance.
on open location targetURL
	if targetURL does not start with "https://" and targetURL does not start with "http://" then
		error "Only HTTP and HTTPS URLs are supported."
	end if
	return my launchChromium(targetURL)
end open location

on run
	my launchChromium("")
end run

on launchChromium(targetURL)
	set browserPath to "/Applications/Chromium.app/Contents/MacOS/Chromium"
	set dataPath to (POSIX path of (path to home folder)) & "Library/Application Support/Chromium"
	do shell script "test -x " & quoted form of browserPath
	set launchCommand to quoted form of browserPath & " " & quoted form of ("--user-data-dir=" & dataPath)
	if targetURL is not "" then set launchCommand to launchCommand & " " & quoted form of targetURL
	return do shell script launchCommand & " >/dev/null 2>&1 &"
end launchChromium
