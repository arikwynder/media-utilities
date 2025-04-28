param(

	$startPath=".\",
	$tune="grain",
	$preset="fast",
	$include='*.mkv',
	$exclude='*.hevc',
	$overwrite,
	$seek,
	$seekTo,
	$output,
	[switch]$extractAudio,
	[switch]$extractSubs,
	[switch]$passthroughAudioExt,
	[switch]$passthroughSubsExt,
	[switch]$forcePath,
	[switch]$h,
	[switch]$help

)

$outputIsLeaf = $false ;
$outputLeafSansExt = $Null ;
$outputDir = $Null ;

function Print-Help {
	Write-Host "Pass '-h' or '-help' to print the below message. Will ignore all other arguments." -ForegroundColor DarkCyan ;
	Write-Host "[video-encode-util: HELP]" -ForegroundColor Green ;
	Write-Host "`t'-startPath [Path to Directory]' - The path to recursively search for files." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: Current Working Directory)" -ForegroundColor Green ;
	Write-Host "`t'-tune [ffmpeg tune]' - Tune to provide to ffmpeg for encoding. See ffmpeg documentation." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: grain)" -ForegroundColor Green ;
	Write-Host "`t'-preset [ffmpeg preset]' - Preset to provide to ffmpeg for encoding. See ffmpeg documentation." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: fast)" -ForegroundColor Green ;
	Write-Host "`t'-include [File Pattern]<,Additional Pattern,...>' - File pattern to pass to Get-ChildItem for inclusion." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: '*.mkv')" -ForegroundColor Green ;
	Write-Host "`t'-exclude [File Pattern]<,Additional Pattern,...>' - File pattern to pass to Get-ChildItem for exclusion." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: '*.hevc')" -ForegroundColor Green ;
	Write-Host "`t'-overwrite [y/n/-y/-n]' - Whether to overwrite files by default, or skip." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: -Left Blank to Ask User for each Conflict-)" -ForegroundColor Green ;
	Write-Host "`t'-seek [Time formated input]' - Time to seek to in videos to start encode from." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: -Left Blank to seek from start of video-)" -ForegroundColor Green ;
	Write-Host "`t'-seekto [Time formated input]' - Time in video to encode to, using original timecodes of stream." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: -Left Blank to encode until end of video-)" -ForegroundColor Green ;
	Write-Host "`t'-output [Path to Directory or File]' - The path to output videos to. Will ask to create if not found." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: -Left Blank to use directory of each video-)`t" -ForegroundColor Green ;
	Write-Host "`t`t`t`t`tIf a specific file is specified, then only one input video is allowed from '-include'." -ForegroundColor DarkGreen ;
	Write-Host "`t'-extractAudio' - All audio will be extracted." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: No)`t" -ForegroundColor Green ;
	Write-Host "`t'-extractSubs' - All subtitles will be extracted." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: No)`t" -ForegroundColor Green ;
	Write-Host "`t'-passthroughExtract' - Audio and subs will be passed to output file without reencode." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: No)`t" -ForegroundColor Green ;
	Write-Host "`t'-forcePath' - If output path is specified, will create it without asking. Does not take arguments." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: No)`n" -ForegroundColor Green ;
	
	Write-Host "Exiting..." -ForegroundColor DarkGreen ;
	Exit;
}

function Print-Output-Path-Error-Text {
	Write-Host "[ERROR]" -ForegroundColor Red ;
	Write-Host "Not a valid path. Path needs to start with a singular drive letter" -ForegroundColor Red ;
	Write-Host "followed by a colon (and slash if further characters follow) -OR-" -ForegroundColor Red ;
	Write-Host "one or two '.' followed by slashes if there are proceeding characters." -ForegroundColor Red ;
	Write-Host "EX: 'C:/Path/To/Directory</OptionalFile.ext>' -OR-" -ForegroundColor Red ;
	Write-Host "    './Path/To/Relative/Directory</OptionalFile.ext>'" -ForegroundColor Red ;
	Write-Host "Illegal characters: '`"<>|*?'. A colon (:) is only allowed following a drive letter." -ForegroundColor Red ;
	Write-Host "Note that any occurence of a slash ('\' or '/') will create a new folder." -ForegroundColor Red ;
	Write-Host "For compatibility with all input streams, only the 'mkv' extension is allowed if file name specified.`n`n" -ForegroundColor Red ;
	
	Print-Help ;
}

function Get-HDR-Color-Data {
	param ( 
		[Parameter(Mandatory)]
		$HDRvid
	)

	$vidRedX = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String red_x).toString()
	$redXStart = $vidRedX.IndexOf("=")+1
	$redXLength = ($vidRedX.IndexOf("/") - $vidRedX.IndexOf("="))-1
	$vidRedX = $vidRedX.Substring($redXStart,$redXLength)
	
	$vidRedY = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String red_y).toString()
	$redYStart = $vidRedY.IndexOf("=")+1
	$redYLength = ($vidRedY.IndexOf("/") - $vidRedY.IndexOf("="))-1
	$vidRedY = $vidRedY.Substring($redYStart,$redYLength)
	
	$vidGreenX = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String green_x).toString()
	$greenXStart = $vidgreenX.IndexOf("=")+1
	$greenXLength = ($vidgreenX.IndexOf("/") - $vidgreenX.IndexOf("="))-1
	$vidgreenX = $vidgreenX.Substring($greenXStart,$greenXLength)
	
	$vidGreenY = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String green_y).toString()
	$greenYStart = $vidgreenY.IndexOf("=")+1
	$greenYLength = ($vidgreenY.IndexOf("/") - $vidgreenY.IndexOf("="))-1
	$vidgreenY = $vidgreenY.Substring($greenYStart,$greenYLength)
	
	$vidBlueX = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String blue_x).toString()
	$blueXStart = $vidblueX.IndexOf("=")+1
	$blueXLength = ($vidblueX.IndexOf("/") - $vidblueX.IndexOf("="))-1
	$vidblueX = $vidblueX.Substring($blueXStart,$blueXLength)
	
	$vidBlueY = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String blue_y).toString()
	$blueYStart = $vidblueY.IndexOf("=")+1
	$blueYLength = ($vidblueY.IndexOf("/") - $vidblueY.IndexOf("="))-1
	$vidblueY = $vidblueY.Substring($blueYStart,$blueYLength)
	
	$vidWhPoX = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String white_point_x).toString()
	$whpoXStart = $vidwhpoX.IndexOf("=")+1
	$whpoXLength = ($vidwhpoX.IndexOf("/") - $vidwhpoX.IndexOf("="))-1
	$vidWhPoX = $vidwhpoX.Substring($whpoXStart,$whpoXLength)
	
	$vidWhPoY = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String white_point_y).toString()
	$whpoYStart = $vidwhpoY.IndexOf("=")+1
	$whpoYLength = ($vidwhpoY.IndexOf("/") - $vidwhpoY.IndexOf("="))-1
	$vidwhpoY = $vidwhpoY.Substring($whpoYStart,$whpoYLength)
	
	$vidminlum = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String min_luminance).toString()
	$minlumStart = $vidminlum.IndexOf("=")+1
	$minlumLength = ($vidminlum.IndexOf("/") - $vidminlum.IndexOf("="))-1
	$vidminlum = $vidminlum.Substring($minlumStart,$minlumLength)
	
	$vidmaxlum = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String max_luminance).toString()
	$maxlumStart = $vidmaxlum.IndexOf("=")+1
	$maxlumLength = ($vidmaxlum.IndexOf("/") - $vidmaxlum.IndexOf("="))-1
	$vidmaxlum = $vidmaxlum.Substring($maxlumStart,$maxlumLength)
	
	$vidmaxcon = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String max_content).toString()
	$maxconStart = $vidmaxcon.IndexOf("=")+1
	$vidmaxcon = $vidmaxcon.Substring($maxconStart)
	
	$vidmaxavg = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid | Select-String max_average).toString()
	$maxavgStart = $vidmaxavg.IndexOf("=")+1
	$vidmaxavg = $vidmaxavg.Substring($maxavgStart)
	
	$hasDynaHDR = (((ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid) | Select-String ("HDR Dynamic Metadata")) -ne $null) -OR (((ffprobe -hide_banner -loglevel warning -select_streams v:0 -print_format json -show_frames -read_intervals "%+#1" -show_entries streams -i $HDRVid) | Select-String ("HDR Dynamic Metadata")) -ne $null)
	$hasDoVi = (((ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $HDRvid) | Select-String ("Dolby Vision Metadata")) -ne $null) -OR (((ffprobe -hide_banner -loglevel warning -select_streams v:0 -print_format json -show_frames -read_intervals "%+#1" -show_entries streams -i $HDRVid) | Select-String ("DOVI configuration record")) -ne $null)
	
	return $vidRedX,$vidRedY,$vidGreenX,$vidGreenY,$vidBlueX,$vidBlueY,$vidWhPoX,$VidWhPoY,$vidminlum,$vidmaxlum,$vidmaxcon,$vidMaxAvg,$hasDynaHDR,$hasDoVi
	
}

function extract-extra-streams {
	param ( 
		[Parameter(Mandatory)]
		$vid,
		$audio,
		$subs,
		$audPassthrough,
		$subPassthrough
	)
	
	if ($output -ne $Null) {
		if ($outputIsLeaf -eq $True) {
			$vidNameSansExt = $outputLeafSansExt ;
		} else {
			$vidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($vid) ;
		}
		$vidDir = $outputDir ;
	} else {
		$vidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($vid) ;
		$vidDir = $vid.FullName | Split-Path
	}
	
	$command = "$overwrite -i '$vid' $seek $seekto " ;
	if ($audio -eq $True) {
		for (($aud = 0) ; ($aud -lt (ffprobe -v error -show_entries stream=codec_type -of default=nk=1:nw=1 $vid | Select-String audio).count) ; $aud++) {
			$codec = (Out-String -InputObject (ffprobe -v error -select_streams a:$aud -show_entries stream=codec_name -of default=nk=1:nw=1 $vid)).Trim() ;
			$codecMeta = $codec.SubString(0) ;
			$channels =  (Out-String -InputObject (ffprobe -v error -select_streams a:$aud -show_entries stream=channels -of default=nk=1:nw=1 $vid)).Trim() ;
			$channels = "${channels}ch"
			$audID = $aud.toString().PadLeft(2,'0') ;
			$audLang = (Out-String -InputObject (ffprobe -v error -select_streams a:$aud -show_entries stream -of default=nk=0:nw=1 $vid | Select-String language)).Trim() ;
			$audLangStart = $audLang.IndexOf("=")+1 ;
			$audLang = $audLang.SubString($audLangStart) ;
			if($audLang.length -eq 0) {
				$audLang = "undLang" ;
			}
			$extension = "wav" ;
			$rf64="-rf64 auto";
			if ($audPassthrough -eq $True) {
				if ($codec.contains("pcm")) {
					$extension = "wav" ;
				} elseif ($codec.contains("alac")) {
					$extension = "m4a" ;
					$rf64 = "-rf64 0";
				} elseif ($codec.contains("flac")) {
					$extension = "flac" ;
					$rf64 = "-rf64 0";
				} elseif ($codec.contains("truehd")) {
					$extension = "truehd" ;
					$rf64 = "-rf64 0";
				} elseif ($codec.contains("eac3")) {
					$extension = "eac3" ;
					$rf64 = "-rf64 0";
				} elseif ($codec.contains("ac3")) {
					$extension = "ac3" ;
					$rf64 = "-rf64 0";
				} else {
					$extension = "mka" ;
					$rf64 = "-rf64 0";
				}
				
				$codec = "copy" ;
			} else {
				$codec = "pcm_s24le" ;
			}
			$outputComm = "$rf64 '$vidDir/$vidNameSansExt.track-$audID.$codecMeta.$channels.$audLang.$extension'" ;
			$command = "$command -map 0:a:$aud -c:a $codec -async 0 $outputComm " ;
		}
	}

	if ($subs -eq $True) {
		for (($sub = 0) ; ($sub -lt (ffprobe -v error -show_entries stream=codec_type -of default=nk=1:nw=1 $vid | Select-String subtitle).count) ; $sub++) {
			$codec = "ass" ;
			$subID = $sub.toString().PadLeft(2,'0') ;
			$subLang = (Out-String -InputObject (ffprobe -v error -select_streams a:$aud -show_entries stream -of default=nk=0:nw=1 $vid | Select-String language)).Trim() ;
			$subLangStart = $subLang.IndexOf("=")+1 ;
			$subLang = $subLang.SubString($subLangStart) ;
			if($subLang.length -eq 0) {
				$subLang = "undLang" ;
			}
			$extension = "ass" ;
			if ($subPassthrough -eq $True) {
				$codec = (Out-String -InputObject (ffprobe -v error -select_streams s:$sub -show_entries stream=codec_name -of default=nk=1:nw=1 $vid)).Trim() ;
				if ($codec.contains("ass")) {
					$extension = "ass" ;
				} elseif ($codec.contains("srt") -OR $codec.contains("subrip")) {
					$extension = "srt" ;
				} elseif ($codec.contains("vtt")) {
					$extension = "vtt" ;
				} elseif ($codec.contains("pgs")) {
					$extension = "sup" ;
				} else {
					$extension = "mks" ;
				}
				$codec = "copy" ;
			}
			$outputComm = "'$vidDir/$vidNameSansExt.track-$subID.$subLang.$extension'" ;
			$command = "$command -map 0:s:$sub -c:s $codec $outputComm " ;
		}
	}
	
	iex "& ffmpeg $command" ;
	
}

function compile-HDR-video {
	param ( 
		[Parameter(Mandatory)]
		$HDRvid,
		$vidExt,
		$vidHeight,
		$vidWidth,
		$vidRedX,
		$vidRedY,
		$vidGreenX,
		$vidGreenY,
		$vidBlueX,
		$vidBlueY,
		$vidWhPoX,
		$VidWhPoY,
		$vidminlum,
		$vidmaxlum,
		$vidmaxcon,
		$vidMaxAvg,
		$bitrate,
		$maxrate,
		$bufsize,
		$framerate,
		$tune,
		$preset
	)
	
	if ($output -ne $Null) {
		if ($outputIsLeaf -eq $True) {
			$HDRVidNameSansExt = $outputLeafSansExt ;
		} else {
			$HDRVidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($vid) ;
		}
		$HDRVidDir = $outputDir ;
	} else {
		$HDRVidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($HDRvid) ;
		$HDRVidDir = $HDRvid.FullName | Split-Path
	}
	
	
	if ($vidExt -eq "hevc") {
		nvencc64 --avhw -i $HDRvid -c hevc --output-depth 10 --lossless --colorrange auto --videoformat ntsc --colormatrix auto --colorprim auto --transfer auto --chromaloc auto --max-cll copy --master-display copy --atc-sei auto --vpp-convolution3d "ythresh=0,cthresh=2,t_ythresh=1,t_cthresh=3" --vpp-edgelevel "strength=2,threshold=30,black=2,white=1" --vpp-deband "range=10,thre_y=5,thre_cb=3,thre_cr=3,dither_y=10,dither_c=4,rand_each_frame" -f hevc -o - | ffmpeg $overwrite -r $framerate -i - -map 0:v:0 -c:v libx265 -x265-params "hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G($vidGreenX,$vidGreenY)B($vidBlueX,$vidBlueY)R($vidRedX,$vidRedY)WP($vidWhPoX,$VidWhPoY)L($vidmaxlum,$vidminlum):max-cll=$vidmaxcon,$vidMaxAvg" -filter:v "scale=3840:-1:force_original_aspect_ratio=decrease,pad=3840:2160:(ow-iw)/2:(oh-ih)/2,setsar=1" -tune $tune -b:v $bitrate -maxrate:v $maxrate -bufsize:v $bufsize -preset $preset -pix_fmt yuv420p10le -fps_mode passthrough -async 0 "$HDRVidDir\$HDRVidNameSansExt.OUT.hevc"
	} elseif ($vidExt -eq "mkv") {
		nvencc64 --avhw -i $HDRvid -c hevc --output-depth 10 --lossless --colorrange auto --videoformat ntsc --colormatrix auto --colorprim auto --transfer auto --chromaloc auto --max-cll copy --master-display copy --atc-sei auto --vpp-convolution3d "ythresh=0,cthresh=2,t_ythresh=1,t_cthresh=3" --vpp-edgelevel "strength=2,threshold=30,black=2,white=1" --vpp-deband "range=10,thre_y=5,thre_cb=3,thre_cr=3,dither_y=10,dither_c=4,rand_each_frame" -f hevc -o - | ffmpeg $overwrite -r $framerate -i - -map 0:v:0 -map 0:a? -map 0:s? -map 0:t? -c:v libx265 -c:a copy -c:s copy -c:t copy -x265-params "hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G($vidGreenX,$vidGreenY)B($vidBlueX,$vidBlueY)R($vidRedX,$vidRedY)WP($vidWhPoX,$VidWhPoY)L($vidmaxlum,$vidminlum):max-cll=$vidmaxcon,$vidMaxAvg" -filter:v "scale=3840:-1:force_original_aspect_ratio=decrease,pad=3840:2160:(ow-iw)/2:(oh-ih)/2,setsar=1" -tune $tune -b:v $bitrate -maxrate:v $maxrate -bufsize:v $bufsize -preset $preset -pix_fmt yuv420p10le -fps_mode passthrough -async 0 "$HDRVidDir\$HDRVidNameSansExt.OUT.mkv"
	} else {
		Write-Host "'$vidExt' is not on the list. Choose from 'hevc' or 'mkv'" -ForegroundColor Red ;
	}
	
	return "$HDRVidDir\$HDRVidNameSansExt.OUT"
	
}

function compile-SDR-video {
	param ( 
		[Parameter(Mandatory)]
		$SDRvid,
		$vidExt,
		$vidHeight,
		$vidWidth,
		$bitrate,
		$maxrate,
		$bufsize,
		$framerate,
		$tune,
		$preset
	)
	
	if ($output -ne $Null) {
		if ($outputIsLeaf -eq $True) {
			$SDRVidNameSansExt = $outputLeafSansExt ;
		} else {
			$SDRVidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($vid) ;
		}
		$SDRVidDir = $outputDir ;
	} else {
		$SDRVidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($SDRvid) ;
		$SDRVidDir = $SDRvid.FullName | Split-Path
	}
	
	
	
	if ($vidExt -eq "hevc") {
		nvencc64 --avhw -i $SDRvid -c hevc --output-depth 10 --lossless --videoformat ntsc --vpp-convolution3d "ythresh=0,cthresh=2,t_ythresh=1,t_cthresh=3" --vpp-edgelevel "strength=2,threshold=30,black=2,white=1" --vpp-deband "range=10,thre_y=5,thre_cb=3,thre_cr=3,dither_y=10,dither_c=4,rand_each_frame" -f hevc -o - | ffmpeg $overwrite -r $framerate -i - -c:v libx265 -filter:v "scale=3840:-1:force_original_aspect_ratio=decrease,pad=3840:2160:(ow-iw)/2:(oh-ih)/2,setsar=1" -tune $tune -b:v $bitrate -maxrate:v $maxrate -bufsize:v $bufsize -preset $preset -pix_fmt yuv420p10le -fps_mode passthrough -async 0 "$SDRVidDir\$SDRVidNameSansExt.OUT.hevc"
	} elseif ($vidExt -eq "mkv") {
		nvencc64 --avhw -i $SDRvid -c hevc --output-depth 10 --lossless --videoformat ntsc --vpp-convolution3d "ythresh=0,cthresh=2,t_ythresh=1,t_cthresh=3" --vpp-edgelevel "strength=2,threshold=30,black=2,white=1" --vpp-deband "range=10,thre_y=5,thre_cb=3,thre_cr=3,dither_y=10,dither_c=4,rand_each_frame" -f hevc -o - | ffmpeg $overwrite -r $framerate -i - -map 0:v:0 -map 0:a? -map 0:s? -map 0:t? -c:v libx265 -c:a copy -c:s copy -c:t copy -filter:v "scale=3840:-1:force_original_aspect_ratio=decrease,pad=3840:2160:(ow-iw)/2:(oh-ih)/2,setsar=1" -tune $tune -b:v $bitrate -maxrate:v $maxrate -bufsize:v $bufsize -preset $preset -pix_fmt yuv420p10le -fps_mode passthrough -async 0 "$SDRVidDir\$SDRVidNameSansExt.OUT.mkv"
	} else {
		Write-Host "'$vidExt' is not on the list. Choose from 'hevc' or 'mkv'" -ForegroundColor Red ;
	}
	
	return "$SDRVidDir\$SDRVidNameSansExt.OUT"
	
}

function mux-x265-raw {
	param ( 
		[Parameter(Mandatory)]
		$vid
	)
	
	if ($output -ne $Null) {
		if ($outputIsLeaf -eq $True) {
			$vidNameSansExt = $outputLeafSansExt ;
		} else {
			$vidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($vid) ;
		}
		$vidDir = $outputDir ;
	} else {
		$vidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($vid) ;
		$vidDir = $vid.DirectoryName ;
	}
	
	
	ffmpeg -i $vid $seek $seekTo -map 0:v:0 -c:v copy -fps_mode passthrough -async 0 "$vidDir\$vidNameSansExt.hevc" $overwrite
	
	
	return "$vidDir\$vidNameSansExt"
	
}

if ($h -eq $True -OR $help -eq $True) {
	Print-Help ;
}

if ((Get-ChildItem -Recurse -Path $startPath -Include $include -Exclude $exclude).Count -lt 1) {
	Write-Host "[ERROR] No videos found for processing. No videos exist or '-include'" -ForegroundColor Red ;
	Write-Host "`tand '-exclude' need to be refined. Exiting..." -ForegroundColor Red ;
	Exit ;
}

if ($forcePath -eq $True -AND $output -eq $Null) {
	Write-Host "[WARNING] -forcePath specified but no output path given. Ignoring..." -ForegroundColor Yellow ;
	$forcePath = $False ;
}

if ($output -ne $Null -AND (-Not ($output -match '^((([A-Za-z]{1}:)((\\+|/+)([A-Za-z0-9])))|((\.{1,2})(\\+|/+)([A-Za-z0-9]))|(([A-Za-z]{1}:)(\\*|/*)$)|((\.{1,2})(\\*|/*)$))'))) {
	Print-Output-Path-Error-Text ;
} elseif ($output.length -gt 0 -AND ($output -match '[`"<>|*?]')) {
	Print-Output-Path-Error-Text ;
} elseif ($output.length -gt 0 -AND (($output.Split(':')).count-1 -gt 1)) {
	Print-Output-Path-Error-Text ;
} elseif ($output.length -gt 0 -AND (($output.Split(':')).count-1 -eq 1) -AND (($output.IndexOf(':') -gt 1) -OR ($output.IndexOf(':') -eq 0))) {
	Print-Output-Path-Error-Text ;
}

if (($output -ne $Null) -AND (Test-Path -literalpath $output -PathType leaf -IsValid) -AND ($output -match "\..{3,5}$")) {
	if ((Get-ChildItem -Recurse -Path $startPath -Include $include -Exclude $exclude).Count -gt 1) {
		Write-Host "[ERROR] Specific output file specified but multiple videos found for processing." -ForegroundColor Red ;
		Write-Host "`tWhen processing multiple videos, specify a directory but not a file. Exiting..." -ForegroundColor Red ;
		Exit ;
	}
	$outputIsLeaf = $true ;
} elseif ($output -eq $Null) {
	$outputIsLeaf = $Null ;
}

if ($outputIsLeaf -ne $Null) {
	$outputName = $output.SubString(0) ;
	
	
	if ((Test-Path -path $output -PathType leaf -IsValid) -AND ($output -match "\..{3,5}$")) {
		$extension = [System.IO.Path]::GetExtension($outputName) ;
		if ($extension -ne "mkv") {
			Print-Output-Path-Error-Text ;
		}
		$outputName = Split-Path $outputName ;
	}
		
	$availableDrives = (Get-PSDrive -PSProvider FileSystem).Root ;
	$writeDriveFound = $False ;
	
	foreach ($drive in $availableDrives) {
		$testDrive = $drive.SubString(0,2)
		if ($outputName.startsWith($testDrive)) {
			Write-Host "Available drive ($testDrive) found in output path" -ForegroundColor DarkYellow ;
			$writeDriveFound = $True;
			Break ;
		}
	}
	
	if ($writeDriveFound -eq $False) {
		$missingDrive = $outputName.SubString(0,2) ;
		Write-Host "[ERROR] Drive ($missingDrive) not found on computer. Exiting..." -ForegroundColor Red ;
		Exit ;
	}
	
	if ((($outputName.length -gt 3) -AND ($outputName -match '^([A-Za-z]:[\\/])')) -AND ((Test-Path $outputName -PathType Container) -eq $False)) {
		if ($forcePath -eq $True) {
			Write-Host "[WARNING] Output path '$outputName' does not exist." -ForegroundColor Yellow ;
			Write-Host "'ForcePath' Specified. Creating '$outputName'..." -ForegroundColor White ;
			New-Item -Path "$outputName" -ItemType Directory -Force ;
		} else {
			Write-Host "[WARNING] Output path '$outputName' does not exist." -ForegroundColor Yellow ;
			$userIn = Read-Host "Would you like to create it? [Y/N]" ;
			if ($userIn.SubString(0,1).toUpper() -eq 'Y') {
				Write-Host "Creating '$outputName'..." -ForegroundColor White ;
				New-Item -Path $outputName -ItemType Directory -Force ;
			} else {
				Write-Host "Not creating path. Exiting..." -ForegroundColor White ;
				Exit ;
			}
		}
	}
	
} else {
	Write-Host "[WARNING] No output specified. Using video paths." -ForegroundColor Yellow ;
}


if ($overwrite -eq "y" -OR $overwrite -eq "n") {
	$overwrite = -join("-",$overwrite)
} elseif ($overwrite -eq "-y" -OR $overwrite -eq "-n" -OR $overwrite -eq $null) {
	#no change needed
} else {
	Write-Host "'$overwrite' is an invalid value for -overwrite. Choose from 'y' or '-y', 'n' or '-n`n" -ForegroundColor Red ;
	Print-Help ;
}

if ($seek -match "-ss ^((\d{2}:\d{2}:\d{2})|(\d{2}:\d{2}:\d{2}\.\d*)|(\d{2}:\d{2})|(\d{2}:\d{2}\.\d*)|(\d+)|(\d*\.\d+))$") {
	$seek = $seek.toLower()
} elseif ($seek -match "^((\d{2}:\d{2}:\d{2})|(\d{2}:\d{2}:\d{2}\.\d*)|(\d{2}:\d{2})|(\d{2}:\d{2}\.\d*)|(\d+)|(\d*\.\d+))$") {
	$seek = -join("-ss ",$seek)
} elseif ($seek -eq $null) {
	#do nothing
} else {
	Write-Host "'$seek' is an invalid value for -seek. Format as '<-ss> ##:##:##<.#*>','<-ss> ##:##<.#*>', or '<-ss> #*<.#*>`n" -ForegroundColor Red ;
	Print-Help ;
}

if ($seekTo -match "-t ^((\d{2}:\d{2}:\d{2})|(\d{2}:\d{2}:\d{2}\.\d*)|(\d{2}:\d{2})|(\d{2}:\d{2}\.\d*)|(\d+)|(\d*\.\d+))$") {
	$seekTo = $seekTo.toLower()
} elseif ($seekTo -match "^((\d{2}:\d{2}:\d{2})|(\d{2}:\d{2}:\d{2}\.\d*)|(\d{2}:\d{2})|(\d{2}:\d{2}\.\d*)|(\d+)|(\d*\.\d+))$") {
	$seekTo = -join("-t ",$seekTo)
} elseif ($seekTo -eq $null) {
	#do nothing
} else {
	Write-Host "'$seekTo' is an invalid value for -seekTo. Format as '<-t> ##:##:##<.#*>','<-t> ##:##<.#*>', or '<-t> #*<.#*>'`n" -ForegroundColor Red ;
	Print-Help ;
}


foreach ($vid in Get-ChildItem -Recurse -Path $startPath -Include $include -Exclude $exclude ) {
	$vidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($vid) ;
	$vidDir = $vid.DirectoryName ; 
	$vidHeight = (ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nk=1:nw=1 $vid) ;
	$vidWidth = (ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nk=1:nw=1 $vid) ;
	$vidColorSp = (ffprobe -v error -select_streams v:0 -show_entries stream=color_space -of default=nk=1:nw=1 $vid) ;
	$vidColorTr = (ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of default=nk=1:nw=1 $vid) ;
	$vidColorPr = (ffprobe -v error -select_streams v:0 -show_entries stream=color_primaries -of default=nk=1:nw=1 $vid) ;
	$framerate = (ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nk=1:nw=1 $vid) ;
	
	if ($output -ne $Null) {
		if ($outputIsLeaf -eq $True) {
			$outputDir = Split-Path $output ;
			$outputLeafSansExt = [System.IO.Path]::GetFileNameWithoutExtension($output) ;
		} else {
			$outputDir = $output ;
		}
	}
	
	Write-Host "Analyzing '$vidNameSansExt'..." -ForegroundColor Green ;

	if ($extractAudio -eq $True -OR $extractSubs -eq $True) {
		
		Extract-Extra-Streams -audio $extractAudio -subs $extractSubs -vid $vid -audPassthrough $passthroughAudioExt -subPassthrough $passthroughSubsExt ;
		
	}

	
	Write-Host "------------" -ForegroundColor Green ;
	Write-Host "Processing '$vidNameSansExt'..." -ForegroundColor Green ;
	
	if ($vidHeight -eq 720 -AND $vidWidth -eq 1280) {
		Write-Host "------------" -ForegroundColor DarkYellow ;
		Write-Host "'$vidNameSansExt' is Wide XGA (" (-join("$vidWidth","x","$vidHeight")) ")" -ForegroundColor DarkYellow ;
		Write-Host "Processing '$vidNameSansExt'..." -ForegroundColor DarkYellow ;
		if ($vidColorSp -eq "bt2020nc" -AND $vidColorTr -eq "smpte2084" -AND $vidColorPr -eq "bt2020") {
			Write-Host "`t'$vidNameSansExt' is HDR" -ForegroundColor Green ;
			$vidRedX,$vidRedY,$vidGreenX,$vidGreenY,$vidBlueX,$vidBlueY,$vidWhPoX,$VidWhPoY,$vidminlum,$vidmaxlum,$vidmaxcon,$vidMaxAvg,$hasDynaHDR,$hasDoVi = Get-HDR-Color-Data $vid ;
			if ($hasDovi -eq $true) {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has Dolby Vison RPUs & HDR10+ SEIs" -ForegroundColor Green ;
					
					$DoviHDR10pVidPath = mux-x265-raw $vid
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.DV.hevc"
					
					dovi_tool -m 5 extract-rpu -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "65M" -maxrate "75M" -bufsize "37M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw "$outputVid.mkv"
					
					$outputDynaHDRVid = "$outputHEVCVid.hevc".replace('HDR10-only','HDR10p')
					$outputDoviDynaHDRVid = $outputDynaHDRVid.replace('HDR10p','DV8-HDR10p')
					$outputDoviDynaHDRMKVVid = $outputDoviDynaHDRVid.replace('hevc','compiled.mkv')
					
					#hdr10plus_tool inject -i "$outputHEVCVid.hevc" -j "$DoviHDR10pVidPath.HDR10p-Data.json" -o $outputDynaHDRVid
					#dovi_tool inject-rpu -i $outputDynaHDRVid --rpu-in "$DoviHDR10pVidPath.DV-Data.bin" -o $outputDoviDynaHDRVid
					
					#mkvmerge -o $outputDoviDynaHDRMKVVid $outputDoviDynaHDRVid
					
					#Remove-Item "$DoviHDR10pVidPath.HDR10p-Data.json" -Force
					#Remove-Item "$DoviHDR10pVidPath.DV-Data.bin" -Force
					#Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force
					
				} else {
					Write-Host "`t'$vidNameSansExt' has Dolby Vison RPUs" -ForegroundColor Green ;
					
					$DoviVidPath = mux-x265-raw $vid
					
					dovi_tool -m 5 extract-rpu -i "$DoviVidPath.hevc" -o "$DoviVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviVidPath.hevc" -o "$DoviVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "24M" -maxrate "32M" -bufsize "16M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw "$outputVid.mkv"
					
					$outputDoviVid = "$outputHEVCVid.hevc".replace('HDR10-only','DV8')
					$outputDoviMKVVid = $outputDoviVid.replace('hevc','compiled.mkv')
					
					#dovi_tool inject-rpu -i "$outputHEVCVid.hevc" --rpu-in "$DoviVidPath.DV-Data.bin" -o $outputDoviVid
					
					#mkvmerge -o $outputDoviVid $outputDoviMKVVid
					
					#Remove-Item "$DoviHDR10pVidPath.DV-Data.bin" -Force
					#Remove-Item "$DoviHDR10pVidPath*.hevc" -Force
				}
			} else {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has HDR10+ SEIs" -ForegroundColor Green ;
					
					$DoviHDR10pVidPath = mux-x265-raw $vid
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "24M" -maxrate "32M" -bufsize "16M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw $outputVid
					
					$outputDynaHDRVid = "$outputHEVCVid.hevc".replace('HDR10-only','HDR10p')
					$outputDynaHDRMKVVid = $outputDynaHDRVid.replace('hevc','compiled.mkv')
					
					#hdr10plus_tool inject -i "$outputHEVCVid.hevc" -j "$DoviHDR10pVidPath.HDR10p-Data.json" -o $outputDynaHDRVid
					
					#mkvmerge -o $outputDoviDynaHDRMKVVid $outputDynaHDRVid
					
					#Remove-Item "$DoviHDR10pVidPath.HDR10p-Data.json" -Force
					#Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force
					
				} else {
					Write-Host "`t'$vidNameSansExt' has no Dynamic HDR metadata" -ForegroundColor Green ;
						
					Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "24M" -maxrate "32M" -bufsize "16M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
				}
			}
		} else {
			Write-Host "`t'$vidNameSansExt' is SDR" -ForegroundColor Green ;
			Compile-SDR-Video -SDRvid $vid -vidExt "mkv" -bitrate "24M" -maxrate "32M" -bufsize "16M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
		}
		Write-Host "------------" -ForegroundColor Blue ;
	} elseif ($vidHeight -eq 1080 -AND $vidWidth -eq 1920) {
		Write-Host "------------" -ForegroundColor Blue ;
		Write-Host "'$vidNameSansExt' is Full HD (" (-join("$vidWidth","x","$vidHeight")) ")" -ForegroundColor Blue ;
		Write-Host "Processing '$vidNameSansExt'..." -ForegroundColor Blue ;
		if ($vidColorSp -eq "bt2020nc" -AND $vidColorTr -eq "smpte2084" -AND $vidColorPr -eq "bt2020") {
			Write-Host "`t'$vidNameSansExt' is HDR" -ForegroundColor Green ;
			$vidRedX,$vidRedY,$vidGreenX,$vidGreenY,$vidBlueX,$vidBlueY,$vidWhPoX,$VidWhPoY,$vidminlum,$vidmaxlum,$vidmaxcon,$vidMaxAvg,$hasDynaHDR,$hasDoVi = Get-HDR-Color-Data $vid ;
			if ($hasDovi -eq $true) {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has Dolby Vison RPUs & HDR10+ SEIs" -ForegroundColor Green ;
					
					$DoviHDR10pVidPath = mux-x265-raw $vid
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.DV.hevc"
					
					dovi_tool -m 5 extract-rpu -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "38M" -maxrate "42M" -bufsize "21M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw "$outputVid.mkv"
					
					$outputDynaHDRVid = "$outputHEVCVid.hevc".replace('HDR10-only','HDR10p')
					$outputDoviDynaHDRVid = $outputDynaHDRVid.replace('HDR10p','DV8-HDR10p')
					$outputDoviDynaHDRMKVVid = $outputDoviDynaHDRVid.replace('hevc','compiled.mkv')
					
					#hdr10plus_tool inject -i "$outputHEVCVid.hevc" -j "$DoviHDR10pVidPath.HDR10p-Data.json" -o $outputDynaHDRVid
					#dovi_tool inject-rpu -i $outputDynaHDRVid --rpu-in "$DoviHDR10pVidPath.DV-Data.bin" -o $outputDoviDynaHDRVid
					
					#mkvmerge -o $outputDoviDynaHDRMKVVid $outputDoviDynaHDRVid
					
					#Remove-Item "$DoviHDR10pVidPath.HDR10p-Data.json" -Force
					#Remove-Item "$DoviHDR10pVidPath.DV-Data.bin" -Force
					#Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force
					
				} else {
					Write-Host "`t'$vidNameSansExt' has Dolby Vison RPUs" -ForegroundColor Green ;
					
					$DoviVidPath = mux-x265-raw $vid
					
					dovi_tool -m 5 extract-rpu -i "$DoviVidPath.hevc" -o "$DoviVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviVidPath.hevc" -o "$DoviVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "38M" -maxrate "42M" -bufsize "21M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw "$outputVid.mkv"
					
					$outputDoviVid = "$outputHEVCVid.hevc".replace('HDR10-only','DV8')
					$outputDoviMKVVid = $outputDoviVid.replace('hevc','compiled.mkv')
					
					#dovi_tool inject-rpu -i "$outputHEVCVid.hevc" --rpu-in "$DoviVidPath.DV-Data.bin" -o $outputDoviVid
					
					#mkvmerge -o $outputDoviVid $outputDoviMKVVid
					
					#Remove-Item "$DoviHDR10pVidPath.DV-Data.bin" -Force
					#Remove-Item "$DoviHDR10pVidPath*.hevc" -Force
				}
			} else {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has HDR10+ SEIs" -ForegroundColor Green ;
					
					$DoviHDR10pVidPath = mux-x265-raw $vid
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "38M" -maxrate "42M" -bufsize "21M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw $outputVid
					
					$outputDynaHDRVid = "$outputHEVCVid.hevc".replace('HDR10-only','HDR10p')
					$outputDynaHDRMKVVid = $outputDynaHDRVid.replace('hevc','compiled.mkv')
					
					#hdr10plus_tool inject -i "$outputHEVCVid.hevc" -j "$DoviHDR10pVidPath.HDR10p-Data.json" -o $outputDynaHDRVid
					
					#mkvmerge -o $outputDoviDynaHDRMKVVid $outputDynaHDRVid
					
					#Remove-Item "$DoviHDR10pVidPath.HDR10p-Data.json" -Force
					#Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force
					
				} else {
					Write-Host "`t'$vidNameSansExt' has no Dynamic HDR metadata" -ForegroundColor Green ;
						
					Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "38M" -maxrate "42M" -bufsize "21M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
				}
			}
		} else {
			Write-Host "`t'$vidNameSansExt' is SDR" -ForegroundColor Green ;
			Compile-SDR-Video -SDRvid $vid -vidExt "mkv" -bitrate "38M" -maxrate "42M" -bufsize "21M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
		}
		Write-Host "------------" -ForegroundColor Blue ;
	} elseif ($vidHeight -eq 1440 -AND $vidWidth -eq 2560) {
		Write-Host "------------" -ForegroundColor Cyan ;
		Write-Host "'$vidNameSansExt' is Quad HD (" (-join("$vidWidth","x","$vidHeight")) ")" -ForegroundColor Cyan ;
		Write-Host "Processing '$vidNameSansExt'..." -ForegroundColor Cyan ;
		if ($vidColorSp -eq "bt2020nc" -AND $vidColorTr -eq "smpte2084" -AND $vidColorPr -eq "bt2020") {
			Write-Host "`t'$vidNameSansExt' is HDR" -ForegroundColor Green ;
			$vidRedX,$vidRedY,$vidGreenX,$vidGreenY,$vidBlueX,$vidBlueY,$vidWhPoX,$VidWhPoY,$vidminlum,$vidmaxlum,$vidmaxcon,$vidMaxAvg,$hasDynaHDR,$hasDoVi = Get-HDR-Color-Data $vid ;
			if ($hasDovi -eq $true) {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has Dolby Vison RPUs & HDR10+ SEIs" -ForegroundColor Green ;
					
					$DoviHDR10pVidPath = mux-x265-raw $vid
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.DV.hevc"
					
					dovi_tool -m 5 extract-rpu -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "54M" -maxrate "62M" -bufsize "31M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw "$outputVid.mkv"
					
					$outputDynaHDRVid = "$outputHEVCVid.hevc".replace('HDR10-only','HDR10p')
					$outputDoviDynaHDRVid = $outputDynaHDRVid.replace('HDR10p','DV8-HDR10p')
					$outputDoviDynaHDRMKVVid = $outputDoviDynaHDRVid.replace('hevc','compiled.mkv')
					
					#hdr10plus_tool inject -i "$outputHEVCVid.hevc" -j "$DoviHDR10pVidPath.HDR10p-Data.json" -o $outputDynaHDRVid
					#dovi_tool inject-rpu -i $outputDynaHDRVid --rpu-in "$DoviHDR10pVidPath.DV-Data.bin" -o $outputDoviDynaHDRVid
					
					#mkvmerge -o $outputDoviDynaHDRMKVVid $outputDoviDynaHDRVid
					
					#Remove-Item "$DoviHDR10pVidPath.HDR10p-Data.json" -Force
					#Remove-Item "$DoviHDR10pVidPath.DV-Data.bin" -Force
					#Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force
					
				} else {
					Write-Host "`t'$vidNameSansExt' has Dolby Vison RPUs" -ForegroundColor Green ;
					
					$DoviVidPath = mux-x265-raw $vid
					
					dovi_tool -m 5 extract-rpu -i "$DoviVidPath.hevc" -o "$DoviVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviVidPath.hevc" -o "$DoviVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "54M" -maxrate "62M" -bufsize "31M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw "$outputVid.mkv"
					
					$outputDoviVid = "$outputHEVCVid.hevc".replace('HDR10-only','DV8')
					$outputDoviMKVVid = $outputDoviVid.replace('hevc','compiled.mkv')
					
					#dovi_tool inject-rpu -i "$outputHEVCVid.hevc" --rpu-in "$DoviVidPath.DV-Data.bin" -o $outputDoviVid
					
					#mkvmerge -o $outputDoviVid $outputDoviMKVVid
					
					#Remove-Item "$DoviHDR10pVidPath.DV-Data.bin" -Force
					#Remove-Item "$DoviHDR10pVidPath*.hevc" -Force
				}
			} else {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has HDR10+ SEIs" -ForegroundColor Green ;
					
					$DoviHDR10pVidPath = mux-x265-raw $vid
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "54M" -maxrate "62M" -bufsize "31M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw $outputVid
					
					$outputDynaHDRVid = "$outputHEVCVid.hevc".replace('HDR10-only','HDR10p')
					$outputDynaHDRMKVVid = $outputDynaHDRVid.replace('hevc','compiled.mkv')
					
					#hdr10plus_tool inject -i "$outputHEVCVid.hevc" -j "$DoviHDR10pVidPath.HDR10p-Data.json" -o $outputDynaHDRVid
					
					#mkvmerge -o $outputDoviDynaHDRMKVVid $outputDynaHDRVid
					
					#Remove-Item "$DoviHDR10pVidPath.HDR10p-Data.json" -Force
					#Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force
					
				} else {
					Write-Host "`t'$vidNameSansExt' has no Dynamic HDR metadata" -ForegroundColor Green ;
						
					Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "54M" -maxrate "62M" -bufsize "31M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
				}
			}
		} else {
			Write-Host "`t'$vidNameSansExt' is SDR" -ForegroundColor Green ;
			Compile-SDR-Video -SDRvid $vid -vidExt "mkv" -bitrate "54M" -maxrate "62M" -bufsize "31M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
		}
		Write-Host "------------" -ForegroundColor Cyan ;
	} elseif ($vidHeight -eq 2160 -AND $vidWidth -eq 3840) {
		Write-Host "------------" -ForegroundColor Magenta ;
		Write-Host "'$vidNameSansExt' is Ultra HD (" (-join("$vidWidth","x","$vidHeight")) ")" -ForegroundColor Magenta ;
		Write-Host "Processing '$vidNameSansExt'..." -ForegroundColor Magenta ;
		
			if ($vidColorSp -eq "bt2020nc" -AND $vidColorTr -eq "smpte2084" -AND $vidColorPr -eq "bt2020") {
			Write-Host "`t'$vidNameSansExt' is HDR" -ForegroundColor Green ;
			$vidRedX,$vidRedY,$vidGreenX,$vidGreenY,$vidBlueX,$vidBlueY,$vidWhPoX,$VidWhPoY,$vidminlum,$vidmaxlum,$vidmaxcon,$vidMaxAvg,$hasDynaHDR,$hasDoVi = Get-HDR-Color-Data $vid ;
			if ($hasDovi -eq $true) {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has Dolby Vison RPUs & HDR10+ SEIs" -ForegroundColor Green ;
					
					$DoviHDR10pVidPath = mux-x265-raw $vid
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.DV.hevc"
					
					dovi_tool -m 5 extract-rpu -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "65M" -maxrate "75M" -bufsize "37M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw "$outputVid.mkv"
					
					$outputDynaHDRVid = "$outputHEVCVid.hevc".replace('HDR10-only','HDR10p')
					$outputDoviDynaHDRVid = $outputDynaHDRVid.replace('HDR10p','DV8-HDR10p')
					$outputDoviDynaHDRMKVVid = $outputDoviDynaHDRVid.replace('hevc','compiled.mkv')
					
					#hdr10plus_tool inject -i "$outputHEVCVid.hevc" -j "$DoviHDR10pVidPath.HDR10p-Data.json" -o $outputDynaHDRVid
					#dovi_tool inject-rpu -i $outputDynaHDRVid --rpu-in "$DoviHDR10pVidPath.DV-Data.bin" -o $outputDoviDynaHDRVid
					
					#mkvmerge -o $outputDoviDynaHDRMKVVid $outputDoviDynaHDRVid
					
					#Remove-Item "$DoviHDR10pVidPath.HDR10p-Data.json" -Force
					#Remove-Item "$DoviHDR10pVidPath.DV-Data.bin" -Force
					#Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force
					
				} else {
					Write-Host "`t'$vidNameSansExt' has Dolby Vison RPUs" -ForegroundColor Green ;
					
					$DoviVidPath = mux-x265-raw $vid
					
					dovi_tool -m 5 extract-rpu -i "$DoviVidPath.hevc" -o "$DoviVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviVidPath.hevc" -o "$DoviVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "65M" -maxrate "75M" -bufsize "37M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw "$outputVid.mkv"
					
					$outputDoviVid = "$outputHEVCVid.hevc".replace('HDR10-only','DV8')
					$outputDoviMKVVid = $outputDoviVid.replace('hevc','compiled.mkv')
					
					#dovi_tool inject-rpu -i "$outputHEVCVid.hevc" --rpu-in "$DoviVidPath.DV-Data.bin" -o $outputDoviVid
					
					#mkvmerge -o $outputDoviVid $outputDoviMKVVid
					
					#Remove-Item "$DoviHDR10pVidPath.DV-Data.bin" -Force
					#Remove-Item "$DoviHDR10pVidPath*.hevc" -Force
				}
			} else {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has HDR10+ SEIs" -ForegroundColor Green ;
					
					$DoviHDR10pVidPath = mux-x265-raw $vid
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"
					
					$outputVid = Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "65M" -maxrate "75M" -bufsize "37M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
					
					$outputHEVCVid = mux-x265-raw $outputVid
					
					$outputDynaHDRVid = "$outputHEVCVid.hevc".replace('HDR10-only','HDR10p')
					$outputDynaHDRMKVVid = $outputDynaHDRVid.replace('hevc','compiled.mkv')
					
					#hdr10plus_tool inject -i "$outputHEVCVid.hevc" -j "$DoviHDR10pVidPath.HDR10p-Data.json" -o $outputDynaHDRVid
					
					#mkvmerge -o $outputDoviDynaHDRMKVVid $outputDynaHDRVid
					
					#Remove-Item "$DoviHDR10pVidPath.HDR10p-Data.json" -Force
					#Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force
					
				} else {
					Write-Host "`t'$vidNameSansExt' has no Dynamic HDR metadata" -ForegroundColor Green ;
						
					Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate "65M" -maxrate "75M" -bufsize "37M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
				}
			}
		} else {
			Write-Host "`t'$vidNameSansExt' is SDR" -ForegroundColor Green ;
			Compile-SDR-Video -SDRvid $vid -vidExt "mkv" -bitrate "65M" -maxrate "75M" -bufsize "37M" -tune $tune -preset $preset -framerate $framerate -vidHeight $vidHeight -vidWidth $vidWidth
		}
	}
	Write-Host "------------" -ForegroundColor Green ;
}

