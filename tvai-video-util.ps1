param(

	$startPath=".\",
	$tune="grain",
	$preset="fast",
	$include='*.mkv',
	$exclude='*.hevc',
	$mode='default',
	$overwrite,
	$seek,
	$seekTo,
	$output,
	$crop,
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

$width = $Null ;
$height = $Null ;
$cropX = $Null ;
$cropY = $Null ;

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
	Write-Host "`t'-mode [mode] - Mode to run process video with." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: 'default' - 'Process video normally')" -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t`t'Other Options:" -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t`t'4krescale' - downscale to 1920p and then up to 4k" -ForegroundColor Green ;
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
		$vidCropX,
		$vidCropY,
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

	if ($mode -eq '4krescale') {
		nvencc64 --avhw -i $HDRVid -c hevc --output-depth 10 --lossless --colorrange auto --videoformat ntsc --colormatrix auto --colorprim auto --transfer auto --chromaloc auto --max-cll copy --master-display copy --atc-sei auto --output-res 1920x-2 --vpp-resize super -o "$HDRVidDir\$HDRVidNameSansExt.tmp.mkv" ;
		$HDRVid = "$HDRVidDir\$HDRVidNameSansExt.tmp.mkv" ;
	}

	$baseFrameRate = [Math]::Log10(24) ;
	$frameRateComp = (ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nk=1:nw=1 $HDRVid).Split("/") ;
	$frameRateScale = [Math]::Log10([double]($frameRateComp[0]) / [double]($frameRateComp[1])) ;
	if ($frameRateComp[0] -ne 1) {
		$framerate = -join($frameRateComp[0],"/",$frameRateComp[1]) ;
	} else {
		$framerate = $frameRateComp[0] ;
	}
	$bitRateScale = [double]($frameRateScale / $baseFrameRate) ;
	$bitrate = -join(([Math]::Ceiling([int]($bitrate.Split("M")[0]) * [double]($bitRateScale))).toString(),"M") ;
	$maxrate = -join(([Math]::Ceiling([int]($maxrate.Split("M")[0]) * [double]($bitRateScale))).toString(),"M") ;
	$bufsize = -join(([Math]::Ceiling([int]($maxrate.Split("M")[0]) / 2)).toString(),"M") ;


	if ($vidExt -eq "hevc") {
	& "C:\Apps\Editors - Media\Topaz Labs LLC\Topaz Video AI\ffmpeg.exe" -hide_banner -loglevel error $overwrite -r $framerate -i $HDRvid -sws_flags spline+accurate_rnd+full_chroma_int -filter_complex "crop=w=${width}:h=${height}:x=${cropX}:y=${cropY},tvai_up=model=rhea-1:scale=0:w=3840:h=2160:preblur=-0.5:noise=0.08:details=0.2:halo=0.3:blur=0.04:compression=0.14:grain=0.01:gsize=2:device=0:vram=0.40:instances=1,scale=w=3840:h=2160:flags=lanczos:threads=0:force_original_aspect_ratio=decrease,pad=3840:2160:-1:-1:color=black" -level 3 -c:v ffv1 -pix_fmt yuv444p12le -slices 4 -slicecrc 1 -g 1 -map 0:a? -c:a copy -map_metadata 0 -map_metadata:s:v 0:s:v -map 0:s? -c:s copy -bf 0 -fps_mode passthrough -async 0 -max_interleave_delta 0 -f nut pipe: | ffmpeg $overwrite -r $framerate -f nut -i pipe: -map 0:v:0 -c:v libx265 -x265-params "hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G($vidGreenX,$vidGreenY)B($vidBlueX,$vidBlueY)R($vidRedX,$vidRedY)WP($vidWhPoX,$VidWhPoY)L($vidmaxlum,$vidminlum):max-cll=$vidmaxcon,$vidMaxAvg" -filter:v "scale=3840:-1:force_original_aspect_ratio=decrease,pad=3840:2160:(ow-iw)/2:(oh-ih)/2,setsar=1" -tune $tune -b:v $bitrate -maxrate:v $maxrate -bufsize:v $bufsize -preset $preset -pix_fmt yuv420p10le -fps_mode passthrough -async 0 -max_interleave_delta 0 $HDRVidDir\$HDRVidNameSansExt.OUT.hevc
	} elseif ($vidExt -eq "mkv") {
		& "C:\Apps\Editors - Media\Topaz Labs LLC\Topaz Video AI\ffmpeg.exe" -hide_banner -loglevel error $overwrite -r $framerate -i $HDRvid -sws_flags spline+accurate_rnd+full_chroma_int -filter_complex "crop=w=${width}:h=${height}:x=${cropX}:y=${cropY},tvai_up=model=rhea-1:scale=0:w=3840:h=2160:preblur=-0.5:noise=0.08:details=0.25:halo=0.3:blur=0.04:compression=0.2:grain=0.01:gsize=2:device=0:vram=0.40:instances=1,scale=w=3840:h=2160:flags=lanczos:threads=0:force_original_aspect_ratio=decrease,pad=3840:2160:-1:-1:color=black" -level 3 -c:v ffv1 -pix_fmt yuv444p12le -slices 4 -slicecrc 1 -g 1 -map 0:a? -c:a copy -map_metadata 0 -map_metadata:s:v 0:s:v -map 0:s? -c:s copy -bf 0 -fps_mode passthrough -async 0 -max_interleave_delta 0 -f nut pipe: | ffmpeg $overwrite -r $framerate -f nut -i pipe: -map 0:v:0 -map 0:a? -map 0:s? -map 0:t? -c:v libx265 -c:a copy -c:s copy -c:t copy -x265-params "hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G($vidGreenX,$vidGreenY)B($vidBlueX,$vidBlueY)R($vidRedX,$vidRedY)WP($vidWhPoX,$VidWhPoY)L($vidmaxlum,$vidminlum):max-cll=$vidmaxcon,$vidMaxAvg" -filter:v "scale=3840:-1:force_original_aspect_ratio=decrease,pad=3840:2160:(ow-iw)/2:(oh-ih)/2,setsar=1" -tune $tune -b:v $bitrate -maxrate:v $maxrate -bufsize:v $bufsize -preset $preset -pix_fmt yuv420p10le -fps_mode passthrough -async 0 $HDRVidDir\$HDRVidNameSansExt.OUT.mkv
	} else {
		Write-Host "'$vidExt' is not on the list. Choose from 'hevc' or 'mkv'" -ForegroundColor Red ;
	}

	if ($mode -eq '4krescale') {
		Remove-Item -literalpath $HDRVid -force ;
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
		$vidCropX,
		$vidCropY,
		$bitrate,
		$maxrate,
		$bufsize,
		$framerate,
		$tune,
		$preset
	)

	$baseFrameRate = [Math]::Log10(24) ;
	$frameRateComp = (ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nk=1:nw=1 $SDRVid).Split("/") ;
	$frameRateScale = [Math]::Log10([double]($frameRateComp[0]) / [double]($frameRateComp[1])) ;
	if ($frameRateComp[0] -ne 1) {
		$framerate = -join($frameRateComp[0],"/",$frameRateComp[1]) ;
	} else {
		$framerate = $frameRateComp[0] ;
	}
	$bitRateScale = [double]($frameRateScale / $baseFrameRate) ;
	$bitrate = -join(([Math]::Ceiling([int]($bitrate.Split("M")[0]) * [double]($bitRateScale))).toString(),"M") ;
	$maxrate = -join(([Math]::Ceiling([int]($maxrate.Split("M")[0]) * [double]($bitRateScale))).toString(),"M") ;
	$bufsize = -join(([Math]::Ceiling([int]($maxrate.Split("M")[0]) / 2)).toString(),"M") ;

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

	if ($mode -eq '4krescale') {
		nvencc64 --avhw -i $HDRVid -c hevc --output-depth 10 --lossless --output-res 1920x-2 --vpp-resize super -o "$SDRVidDir\$SDRVidNameSansExt.tmp.mkv" ;
		$SDRVid = "$SDRVidDir\$SDRVidNameSansExt.tmp.mkv" ;
	}



	if ($vidExt -eq "hevc") {
		& "C:\Apps\Editors - Media\Topaz Labs LLC\Topaz Video AI\ffmpeg.exe" -hide_banner -loglevel error $overwrite -r $framerate -i $SDRvid -sws_flags spline+accurate_rnd+full_chroma_int -filter_complex "crop=w=${width}:h=${height}:x=${cropX}:y=${cropY},tvai_up=model=rhea-1:scale=0:w=3840:h=2160:preblur=-0.5:noise=0.08:details=0.2:halo=0.3:blur=0.04:compression=0.14:grain=0.01:gsize=2:device=0:vram=0.40:instances=1,scale=w=3840:h=2160:flags=lanczos:threads=0:force_original_aspect_ratio=decrease,pad=3840:2160:-1:-1:color=black" -level 3 -c:v ffv1 -pix_fmt yuv444p12le -slices 4 -slicecrc 1 -g 1 -map 0:a? -c:a copy -map_metadata 0 -map_metadata:s:v 0:s:v -map 0:s? -c:s copy -bf 0 -fps_mode passthrough -async 0 -max_interleave_delta 0 -f nut pipe: | ffmpeg $overwrite -r $framerate -f nut -i pipe: -c:v libx265 -filter:v "scale=3840:-1:force_original_aspect_ratio=decrease,pad=3840:2160:(ow-iw)/2:(oh-ih)/2,setsar=1" -tune $tune -b:v $bitrate -maxrate:v $maxrate -bufsize:v $bufsize -preset $preset -pix_fmt yuv420p10le -fps_mode passthrough -async 0 -max_interleave_delta 0 $SDRVidDir\$SDRVidNameSansExt.OUT.hevc
	} elseif ($vidExt -eq "mkv") {
	& "C:\Apps\Editors - Media\Topaz Labs LLC\Topaz Video AI\ffmpeg.exe" -hide_banner -loglevel error $overwrite -r $framerate -i $SDRvid -sws_flags spline+accurate_rnd+full_chroma_int -filter_complex "crop=w=${width}:h=${height}:x=${cropX}:y=${cropY},tvai_up=model=rhea-1:scale=0:w=3840:h=2160:preblur=-0.5:noise=0.08:details=0.2:halo=0.3:blur=0.04:compression=0.14:grain=0.01:gsize=2:device=0:vram=0.40:instances=1,scale=w=3840:h=2160:flags=lanczos:threads=0:force_original_aspect_ratio=decrease,pad=3840:2160:-1:-1:color=black" -level 3 -c:v ffv1 -pix_fmt yuv444p12le -slices 4 -slicecrc 1 -g 1 -map 0:a? -c:a copy -map_metadata 0 -map_metadata:s:v 0:s:v -map 0:s? -c:s copy -fps_mode passthrough -async 0 -max_interleave_delta 0 -f nut - | ffmpeg $overwrite -r $framerate -f nut -i - -map 0:v:0 -map 0:a? -map 0:s? -map 0:t? -c:v libx265 -c:a copy -c:s copy -c:t copy -filter:v "scale=3840:-1:force_original_aspect_ratio=decrease,pad=3840:2160:(ow-iw)/2:(oh-ih)/2,setsar=1" -tune $tune -b:v $bitrate -maxrate:v $maxrate -bufsize:v $bufsize -preset $preset -pix_fmt yuv420p10le -fps_mode passthrough -async 0 -max_interleave_delta 0 "$SDRVidDir\$SDRVidNameSansExt.OUT.mkv"
	} else {
		Write-Host "'$vidExt' is not on the list. Choose from 'hevc' or 'mkv'" -ForegroundColor Red ;
	}

	if ($mode -eq '4krescale') {
		Remove-Item -literalpath $SDRVid -force ;
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

if ($crop -ne $NULL -AND -NOT ($crop -match "\d+x\d+x\d+x\d+")) {
		Write-Host "[ERROR] -crop parameter '$crop' does not match necessary format." -ForegroundColor Red ;
		Write-Host "`t-crop takes an argument formatted as 'width,height,cropX,cropY'. There should be no negative numbers. Exiting..." -ForegroundColor Red ;
		Exit ;
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

foreach ($vid in Get-ChildItem -Recurse -literalPath $startPath -Include $include -Exclude $exclude ) {
	$vidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($vid) ;
	$vidDir = $vid.DirectoryName ;
	$vidHeight = (ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nk=1:nw=1 $vid) ;
	$vidWidth = (ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nk=1:nw=1 $vid) ;
	$vidColorSp = (ffprobe -v error -select_streams v:0 -show_entries stream=color_space -of default=nk=1:nw=1 $vid) ;
	$vidColorTr = (ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of default=nk=1:nw=1 $vid) ;
	$vidColorPr = (ffprobe -v error -select_streams v:0 -show_entries stream=color_primaries -of default=nk=1:nw=1 $vid) ;

	$cropData = $crop.split('x') ;

	$vidWidthComp = $vidWidth ;
	$vidHeightComp = $vidHeight ;

	if ($mode -eq '4krescale') {
		$vidWidthComp = $vidWidthComp / 2 ;
		$vidHeightComp = $vidHeightComp / 2 ;
	}

	echo $cropData

	if (([int]$cropData[0] + [int]$cropData[2]) -gt $vidWidthComp) {
		Write-Host "[ERROR] Crop parameter for width is greater than the video ($cropData[0] x $cropData[2] x $vidWidthComp)" -ForegroundColor Red ;
		Write-Host "`tCrop width and X location sum must not exceed video width. If using mode '4krescale', account for the scale to FHD. Skipping video..." -ForegroundColor Red ;
		continue;
	}

	if (([int]$cropData[1] + [int]$cropData[3]) -gt $vidHeightComp) {
		Write-Host "[ERROR] Crop parameter for height is greater than the video ($cropData[1] x $cropData[3] x $vidHeightComp)" -ForegroundColor Red ;
		Write-Host "`tCrop height and Y location sum must not exceed video height. If using mode '4krescale', account for the scale to FHD.  Skipping video..." -ForegroundColor Red ;
		continue;
	}
	if ($cropData -ne $NULL) {
		$width = $cropData[0] ;
		$height = $cropData[1] ;
		$cropX = $cropData[2] ;
		$cropY = $cropData[3] ;
	} else {
		$width = $vidWidth ;
		$height = $vidHeight ;
		$cropX = 0 ;
		$cropY = 0 ;
	}


	$vidBitRate = "68M"
	$vidMaxRate = "84M"
	$vidBufSize = "42M"

	if ($output -ne $Null) {
		if ($outputIsLeaf -eq $True) {
			$outputDir = Split-Path $output ;
			$outputLeafSansExt = [System.IO.Path]::GetFileNameWithoutExtension($output) ;
			Write-Host $outputDir "----------" $outputLeafSansExt -ForegroundColor Green
		} else {
			$outputDir = $output ;
			Write-Host $outputDir "----------" -ForegroundColor Green
		}
	}

	Write-Host "Analyzing '$vidNameSansExt'..." -ForegroundColor Green ;
	Write-Host "Processing '$vidNameSansExt'..."
	if ($vidColorSp -eq "bt2020nc" -AND $vidColorTr -eq "smpte2084" -AND $vidColorPr -eq "bt2020") {
			Write-Host "`t'$vidNameSansExt' is HDR" ;
			$vidRedX,$vidRedY,$vidGreenX,$vidGreenY,$vidBlueX,$vidBlueY,$vidWhPoX,$VidWhPoY,$vidminlum,$vidmaxlum,$vidmaxcon,$vidMaxAvg,$hasDynaHDR,$hasDoVi = Get-HDR-Color-Data $vid ;
			if ($hasDovi -eq $true) {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has Dolby Vison RPUs & HDR10+ SEIs" ;

					$DoviHDR10pVidPath = mux-x265-raw $vid
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.DV.hevc"

					dovi_tool -m 5 extract-rpu -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"

					$outputVid = Compile-HDR-Video -HDRvid "$DoviHDR10pVidPath.HDR10-only.hevc" -vidExt "hevc" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate $vidBitRate -maxrate $vidMaxRate -bufsize $vidBufSize -tune $tune -preset $preset

					$outputDynaHDRVid = "$outputVid.hevc".replace('HDR10-only','HDR10p')
					$outputDoviDynaHDRVid = $outputDynaHDRVid.replace('HDR10p','DV8-HDR10p')
					$outputDoviDynaHDRMKVVid = $outputDoviDynaHDRVid.replace('hevc','mkv')

					hdr10plus_tool inject -i "$outputVid.hevc" -j "$DoviHDR10pVidPath.HDR10p-Data.json" -o $outputDynaHDRVid
					dovi_tool inject-rpu -i $outputDynaHDRVid -rpu-in "$DoviHDR10pVidPath.DV-Data.bin" -o $outputDoviDynaHDRVid

					mkvmerge -o $outputDoviDynaHDRMKVVid $outputDoviDynaHDRVid

					Remove-Item "$DoviHDR10pVidPath.HDR10p-Data.json" -Force
					Remove-Item "$DoviHDR10pVidPath.DV-Data.bin" -Force
					Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force
				} else {
					Write-Host "`t'$vidNameSansExt' has Dolby Vison RPUs" ;

					$DoviVidPath = mux-x265-raw $vid

					dovi_tool -m 5 extract-rpu -i "$DoviVidPath.hevc" -o "$DoviVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviVidPath.hevc" -o "$DoviVidPath.HDR10-only.hevc"

					$outputVid = Compile-HDR-Video -HDRvid "$DoviVidPath.HDR10-only.hevc" -vidExt "hevc" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate $vidBitRate -maxrate $vidMaxRate -bufsize $vidBufSize -tune $tune -preset $preset

					$outputDoviVid = "$outputVid.hevc".replace('HDR10-only','DV8')
					$outputDoviMKVVid = $outputDoviVid.replace('hevc','mkv')

					dovi_tool inject-rpu -i "$outputVid.hevc" -rpu-in "$DoviVidPath.DV-Data.bin" -o $outputDoviVid

					mkvmerge -o $outputDoviVid $outputDoviMKVVid

					Remove-Item "$DoviVidPath.DV-Data.bin" -Force
					Remove-Item "$DoviVidPath.*.hevc" -Force
				}

			} else {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has HDR10+ SEIs" ;

					$DoviHDR10pVidPath = mux-x265-raw $vid
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"

					$outputVid = Compile-HDR-Video -HDRvid "$DoviHDR10pVidPath.HDR10-only.hevc" -vidExt "hevc" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate $vidBitRate -maxrate $vidMaxRate -bufsize $vidBufSize -tune $tune -preset $preset

					$outputDynaHDRVid = "$outputVid.hevc".replace('HDR10-only','HDR10p')

					hdr10plus_tool inject -i "$outputVid.hevc" -j "$DoviHDR10pVidPath.HDR10p-Data.json" -o $outputDynaHDRVid

					mkvmerge -o $outputDoviDynaHDRMKVVid $outputDynaHDRVid

					Remove-Item "$DoviHDR10pVidPath.HDR10p-Data.json" -Force
					Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force

				} else {
					Write-Host "`t'$vidNameSansExt' has no Dynamic HDR metadata" ;

					Compile-HDR-Video -HDRvid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -bitrate $vidBitRate -maxrate $vidMaxRate -bufsize $vidBufSize -tune $tune -preset $preset
				}
			}
		}
	else {
			Write-Host "`t'$vidNameSansExt' is SDR" ;
			Compile-SDR-Video -SDRvid $vid -vidExt "mkv" -bitrate $vidBitRate -maxrate $vidMaxRate -bufsize $vidBufSize -tune $tune -preset $preset
	}
	Write-Host "------------"
}

