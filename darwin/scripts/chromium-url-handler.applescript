-- Launch Services registers the real browser process; the explicit data directory
-- lets Chromium route URLs to the main profile rather than an isolated app.
property remoteDebuggingEnabled : false
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
	set browserPath to "/Applications/Chromium.app"
	set dataPath to (POSIX path of (path to home folder)) & "Library/Application Support/Chromium"
	do shell script "test -x " & quoted form of (browserPath & "/Contents/MacOS/Chromium")
	set launchCommand to "/usr/bin/open -n -a " & quoted form of browserPath & " --args " & quoted form of ("--user-data-dir=" & dataPath)
	if remoteDebuggingEnabled then set launchCommand to launchCommand & " --remote-debugging-port=9222"
	if targetURL is not "" then set launchCommand to launchCommand & " " & quoted form of targetURL
	return do shell script launchCommand
end launchChromium
