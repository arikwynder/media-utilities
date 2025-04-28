param(
	$path='.\',
	$outputPath='.\',
	$include='*.m4b',
	$exclude='*.txt'
 )
 
 if (-Not (Test-Path -IsValid -Path $outputPath)) {
	 Write-Host "[Error] Output path is invalid. Exiting..." -ForegroundColor Red
	 Exit
 }

foreach ($abk in Get-ChildItem -Recurse -Path $path -Include $include -Exclude $exclude ) {
	$series = (ffprobe -v quiet -of default=nk=1:nw=1 -show_entries format_tags=album $abk)
	$bookNum = (ffprobe -v quiet -of default=nk=1:nw=1 -show_entries format_tags=track $abk).PadLeft(2,'0')
	$title = (ffprobe -v quiet -of default=nk=1:nw=1 -show_entries format_tags=title $abk)
	$pubDate = (ffprobe -v quiet -of default=nk=1:nw=1 -show_entries format_tags=date $abk)
	$pubDateShort = $pubDate.SubString(0,4)
	$author = (ffprobe -v quiet -of default=nk=1:nw=1 -show_entries format_tags=artist $abk)
	$performer = (ffprobe -v quiet -of default=nk=1:nw=1 -show_entries format_tags=composer $abk)
	$chapters = @(ffprobe -v quiet -of default=nk=1:nw=1 -show_entries chapter_tags=title $abk )
	$chaptersStart = @(ffprobe -v quiet -of default=nk=1:nw=1 -show_entries chapter=start_time $abk )
	$chaptersEnd = @(ffprobe -v quiet -of default=nk=1:nw=1 -show_entries chapter=end_time $abk )
	
	$outputDestination = "$author\$series\$bookNum. $title ($pubDateShort)".Replace(":","-").Replace('"',"'")
	
	New-Item -ItemType Directory -Path "$outputPath\$outputDestination".Replace(":","-").Replace('"',"'")
	
	ffmpeg -i $abk -map 0:v:0 -c:v copy "$outputPath\$outputDestination\cover.jpg"
	
	for($chap = 0 ; $chap -lt $chapters.count ; $chap++) {
		$chapID = $chap+1
		$chapPad = ([String]$chapID).PadLeft(2,'0')
		$chapName = $chapters[$chap].toString()
		$fullOut = ("${outputPath}\${outputDestination}\${chapPad}. ${chapName}").toString().Replace(":","-").Replace('"',"'")
		ffmpeg -n -ss $chaptersStart[$chap] -to $chaptersEnd[$chap] -i $abk -map 0:a:0 -map_chapters -1 -c copy -movflags faststart -metadata title="$chapName" -metadata album="${series}, Book ${bookNum}, ${title}" -metadata track="$chapID" -async 0 "$fullOut.m4b"
	}
	
}