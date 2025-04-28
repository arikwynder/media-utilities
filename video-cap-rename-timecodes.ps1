param (

	$startPath=".\",
	$addTime="0.0415",
	$startTime="",
	$movie="",
	$chapter=""
)

if ($movie.length -le 0 -OR $chapter.length -le 0) {
	Write-Host "[ERROR] Either -movie or -chapter not given value. Exiting..." -ForgroundColor Red
	exit
}

if ($startTime.length -le 0) {
	Write-Host "[ERROR] -startTime not given value. Exiting..." -ForgroundColor Red
	exit
}


$sec = ([TimeSpan]::Parse("$startTime")).TotalSeconds ;

foreach ($i in Get-ChildItem -Path $startPath -Recurse -Include *.png,*.tif*,*.jp*) {
	$j = [System.IO.Path]::GetFileNameWithoutExtension($i) ;
	$e = [System.IO.Path]::GetExtension($i) ;
	$k = $i.DirectoryName ; $ts =  [timespan]::fromseconds($sec) ;
	$tsf = ("{0:h\_mm\_ss\_fff}" -f $ts) ;
	Rename-Item -Path "$startPath\$j$e" -NewName "$movie, $chapter ($tsf)$e" -Force ;
	$sec = $sec + [double]$addTime
}