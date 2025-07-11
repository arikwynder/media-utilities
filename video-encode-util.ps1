param(

	$startPath=".\",
	$tune="grain",
	$preset="medium",
	$include='*.mkv',
	$exclude='*.hevc',
	$seek,
	$seekTo,
	$output,
	[int]$HDRMaxCon,
	[int]$HDRMaxAvg,
	[int]$compressionTier=1,
	[String]$aspectRatio='16:9',
	[switch]$antialias,
	[switch]$encodeFLAC,
	[switch]$favorCommercialDimensions,
	[switch]$noPadding,
	[switch]$forceSDR,
	[switch]$extractAudio,
	[switch]$extractSubs,
	[switch]$passthroughAudioExt,
	[switch]$passthroughSubsExt,
	[switch]$restore,
	[switch]$forcePath,
	[switch]$overwrite,
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
	Write-Host "`t`t`t`t`t(Default: '*.hevc')" -ForegroundColor Green ;
	Write-Host "`t'-overwrite [y/n/-y/-n]' - Whether to overwrite files by default, or skip." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: -Left Blank to Ask User for each Conflict-)" -ForegroundColor Green ;
	Write-Host "`t'-seek [Time formated input]' - Time to seek to in videos to start encode from." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: 0)" -ForegroundColor Green ;
	Write-Host "`t'-seekto [Time formated input]' - Time in video to encode to, using original timecodes of stream." -ForegroundColor Green ;
	Write-Host "`tIf time is negative (IE. if the argument is preceded with '-', it will subtract from the end ('-##:##:##<.#*>' is acceptable).`n" -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: 59:59:59.999)" -ForegroundColor Green ;
	Write-Host "`t'-output [Path to Directory or File]' - The path to output videos to. Will ask to create if not found." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: -Left Blank to use directory of each video-)`t" -ForegroundColor Green ;
	Write-Host "`t`t`t`t`tIf a specific file is specified, then only one input video is allowed from '-include'." -ForegroundColor DarkGreen ;
	Write-Host "`t'-extractAudio' - All audio will be extracted as pcm." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: No)`t" -ForegroundColor Green ;
	Write-Host "`t'-extractSubs' - All subtitles will be extracted." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: No)`t" -ForegroundColor Green ;
	Write-Host "`t'-passthroughExtract' - Audio and subs will be passed to output file without reencode." -ForegroundColor Green ;
	Write-Host "`t`t`t`t`t(Default: No)`t" -ForegroundColor Green ;
	Write-Host "`t`t`t`t`tNote: if video contains image-based subs, this switch must be used as ffmpeg does not support pgs-to-text encode`t" -ForegroundColor Green ;
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

function extract-extra-streams {
	param (
		[Parameter(Mandatory)]
		$vid,
		$audio,
		$subs,
		$audPassthrough,
		$subPassthrough,
		$vidNameSansExt,
		$vidDir
	)


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

function Get-HDR-Color-Data {
	param (
		[Parameter(Mandatory)]
		$vid
	)

	$vidRedX = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String red_x).toString()
	$redXStart = $vidRedX.IndexOf("=")+1
	$redXLength = ($vidRedX.IndexOf("/") - $vidRedX.IndexOf("="))-1
	$vidRedX = $vidRedX.Substring($redXStart,$redXLength)

	$vidRedY = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String red_y).toString()
	$redYStart = $vidRedY.IndexOf("=")+1
	$redYLength = ($vidRedY.IndexOf("/") - $vidRedY.IndexOf("="))-1
	$vidRedY = $vidRedY.Substring($redYStart,$redYLength)

	$vidGreenX = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String green_x).toString()
	$greenXStart = $vidgreenX.IndexOf("=")+1
	$greenXLength = ($vidgreenX.IndexOf("/") - $vidgreenX.IndexOf("="))-1
	$vidgreenX = $vidgreenX.Substring($greenXStart,$greenXLength)

	$vidGreenY = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String green_y).toString()
	$greenYStart = $vidgreenY.IndexOf("=")+1
	$greenYLength = ($vidgreenY.IndexOf("/") - $vidgreenY.IndexOf("="))-1
	$vidgreenY = $vidgreenY.Substring($greenYStart,$greenYLength)

	$vidBlueX = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String blue_x).toString()
	$blueXStart = $vidblueX.IndexOf("=")+1
	$blueXLength = ($vidblueX.IndexOf("/") - $vidblueX.IndexOf("="))-1
	$vidblueX = $vidblueX.Substring($blueXStart,$blueXLength)

	$vidBlueY = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String blue_y).toString()
	$blueYStart = $vidblueY.IndexOf("=")+1
	$blueYLength = ($vidblueY.IndexOf("/") - $vidblueY.IndexOf("="))-1
	$vidblueY = $vidblueY.Substring($blueYStart,$blueYLength)

	$vidWhPoX = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String white_point_x).toString()
	$whpoXStart = $vidwhpoX.IndexOf("=")+1
	$whpoXLength = ($vidwhpoX.IndexOf("/") - $vidwhpoX.IndexOf("="))-1
	$vidWhPoX = $vidwhpoX.Substring($whpoXStart,$whpoXLength)

	$vidWhPoY = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String white_point_y).toString()
	$whpoYStart = $vidwhpoY.IndexOf("=")+1
	$whpoYLength = ($vidwhpoY.IndexOf("/") - $vidwhpoY.IndexOf("="))-1
	$vidwhpoY = $vidwhpoY.Substring($whpoYStart,$whpoYLength)

	$vidminlum = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String min_luminance).toString()
	$minlumStart = $vidminlum.IndexOf("=")+1
	$minlumLength = ($vidminlum.IndexOf("/") - $vidminlum.IndexOf("="))-1
	$vidminlum = $vidminlum.Substring($minlumStart,$minlumLength)

	$vidmaxlum = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String max_luminance).toString()
	$maxlumStart = $vidmaxlum.IndexOf("=")+1
	$maxlumLength = ($vidmaxlum.IndexOf("/") - $vidmaxlum.IndexOf("="))-1
	$vidmaxlum = $vidmaxlum.Substring($maxlumStart,$maxlumLength)

	$vidmaxcon = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String max_content) ;
	if ( $vidmaxCon -ne $NULL ) {
		$vidMaxCon = $vidMaxCon.toString() ;
		$maxconStart = $vidmaxcon.IndexOf("=")+1 ;
		$vidmaxcon = $vidmaxcon.Substring($maxconStart) ;
	} else {
		Write-Host "`tVidMaxCon is null. Using Default Value: 1000." ;
		$vidmaxCon = 1000 ;
	}

	$vidmaxavg = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid | Select-String max_average) ;
	if ( $vidmaxAvg -ne $NULL ) {
		$vidmaxAvg = $vidmaxAvg.toString()
		$maxavgStart = $vidmaxavg.IndexOf("=")+1
		$vidmaxavg = $vidmaxavg.Substring($maxavgStart)
	} else {
		Write-Host "`tVidMaxAvg is null. Using Default Value: 400." ;
		$vidmaxAvg = 400 ;
	}

	$vidMeta = (ffprobe -v error -read_intervals "%+#1" -select_streams v:0 -show_frames -show_entries frame -of default=nk=0:nw=1 $vid)
	$hasDynaHDR = ($vidMeta | Select-String ("HDR Dynamic Metadata")) -ne $null
	$hasDoVi = ($vidMeta | Select-String ("Dolby Vision Metadata")) -ne $null

	return $vidRedX,$vidRedY,$vidGreenX,$vidGreenY,$vidBlueX,$vidBlueY,$vidWhPoX,$VidWhPoY,$vidminlum,$vidmaxlum,$vidmaxcon,$vidMaxAvg,$hasDynaHDR,$hasDoVi

}

function compile-HDR-video {
	param (
		[Parameter(Mandatory)]
		$vid,
		$vidExt,
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
		$vidWidth,
		$vidHeight,
		$tune,
		$preset,
		$vidAspectRatio,
		$vidNameSansExt,
		$vidDir
	)


	$aspectRatioTop = [int]$aspectRatio.split(":")[0]; #width
	$aspectRatioBot = [int]$aspectRatio.split(":")[1]; #height
	$vidAspectRatioTop = [int]$vidAspectRatio.split(":")[0]; #width
	$vidAspectRatioBot = [int]$vidAspectRatio.split(":")[1]; #height

	$crf = 12 + (($compressionTier-1)*3);

	$bufWidth = $vidWidth ;
	$bufHeight = $vidHeight ;
	$scaleWidth = $vidWidth ;
	$scaleHeight = $vidHeight ;

	 # example being if we have a 1440x1080p video and want 16:9 AR, width = 1080 * 16/9
	 # alternatively, we have 1920x800p video and want 16:9 AR, height = 1920 * 9/16
	if ($vidAspectRatioBot -gt $vidAspectRatioTop) {
		Write-Host "`tAspect Ratio is Portrait" ;
		if ($favorCommercialDimensions) {
			if ($vidHeight -le 1080) {
				$scaleHeight = 1080
				$bufHeight = 1080
			} else {
				$scaleHeight = 2160
				$bufHeight = 2160
			}
		}
		$bufWidth = [Math]::Ceiling([int]$bufHeight*(${aspectRatioTop}/${aspectRatioBot})) ;
		$scaleWidth = -2 ;
	} else {
		Write-Host "`tAspect Ratio is Landscape or Square" ;
		if ($favorCommercialDimensions) {
			if ($vidWidth -le 1920) {
				$scaleWidth = 1920
				$bufWidth = 1920
			} else {
				$scaleWidth = 3840
				$bufWidth = 3840
			}
		}
		$bufHeight = [Math]::Ceiling([int]$bufWidth*(${aspectRatioBot}/${aspectRatioTop})) ;
		$scaleHeight = -2 ;
	}

	if (($bufWidth % 2) -ne 0) {
		$bufWidth++;
	}
	if (($bufHeight % 2) -ne 0) {
		$bufHeight++;
	}

	$frameRate = (ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nk=1:nw=1 $vid).Split("/") ;
	if ($frameRate.size -eq 1) {
		$frameRate = $frameRate[1];
	} elseif ($frameRate[1] -eq 0) {
		$frameRate = $frameRate[1];
	} else {
		$frameRate = $frameRate[0] + "/" + $frameRate[1];
	}


	$filter = "scale=${scaleWidth}:${scaleheight}:force_original_aspect_ratio=decrease,pad=${bufWidth}:${bufHeight}:(ow-iw)/2:(oh-ih)/2,setsar=1"
	if ($antialias) {
		$filter = -join("hqx=4,",$filter);
	}


	if ($restore) {


		if ($vidExt -eq "hevc") {
			nvencc64 --log-level warn -c hevc --avhw -i $vid --output-depth 10 --lossless --videoformat ntsc --colorrange auto --videoformat ntsc --colormatrix auto --colorprim auto --transfer auto --chromaloc auto --max-cll copy --master-display copy --vpp-convolution3d "ythresh=0,cthresh=4,t_ythresh=1,t_cthresh=6" --vpp-libplacebo-deband "iterations=6,threshold=6,radius=18,grain_y=10,grain_c=1" -f hevc -o - | ffmpeg -f hevc -r "$frameRateString" -hwaccel cuda -hwaccel_device 0 -hwaccel_output_format cuda -y -i - -ss $seek -to $seekTo -map 0:v:0 -map 0:a? -map 0:s? -c:v libx265 -c:a $acodec -c:s copy -filter:v $filter -preset $preset -tune $tune -pix_fmt yuv420p10le -crf $crf -fps_mode passthrough -async 0 -sws_flags lanczos -movflags +faststart "$vidDir\$vidNameSansExt.OUT.$vidExt"
		} elseif ($vidExt -eq "mkv") {
			nvencc64 --log-level warn -c hevc --avhw -i $vid --seek $seek --seekto $seekTo --output-depth 10 --lossless --videoformat ntsc --colorrange auto --videoformat ntsc --colormatrix auto --colorprim auto --transfer auto --chromaloc auto --max-cll copy --master-display copy --audio-copy --sub-copy --chapter-copy --videoformat ntsc --vpp-convolution3d "ythresh=0,cthresh=4,t_ythresh=1,t_cthresh=6" --vpp-libplacebo-deband "iterations=6,threshold=6,radius=18,grain_y=10,grain_c=1" -f nut -o - | ffmpeg -f nut -r "$frameRateString" -y -i - -map 0:v:0 -map 0:a? -map 0:s? -c:v libx265 -c:a $acodec -c:s copy -filter:v $filter -preset $preset -tune $tune -pix_fmt yuv420p10le -crf $crf -fps_mode passthrough -async 0 -sws_flags lanczos -movflags +faststart "$vidDir\$vidNameSansExt.OUT.$vidExt"
		} else {
			Write-Host "'$vidExt' is not on the list. Choose from 'hevc' or 'mkv'" -ForegroundColor Red ;
			exit
		}

	} else {

		if ($vidExt -eq "hevc") {
			ffmpeg -y -i $vid -ss $seek -to $seekTo -map 0:v:0 -c:v libx265 -x265-params "hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G($vidGreenX,$vidGreenY)B($vidBlueX,$vidBlueY)R($vidRedX,$vidRedY)WP($vidWhPoX,$VidWhPoY)L($vidmaxlum,$vidminlum):max-cll=$vidmaxcon,$vidMaxAvg" -preset $preset -tune $tune -pix_fmt yuv420p10le -crf $crf -fps_mode passthrough -async 0 -movflags +faststart "$vidDir\$vidNameSansExt.OUT.$vidExt"
		} elseif ($vidExt -eq "mkv") {
			ffmpeg -y -i $vid -ss $seek -to $seekTo -map 0:v:0 -map 0:a? -map 0:s? -c:v libx265 -c:a $acodec -c:s copy -x265-params "hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G($vidGreenX,$vidGreenY)B($vidBlueX,$vidBlueY)R($vidRedX,$vidRedY)WP($vidWhPoX,$VidWhPoY)L($vidmaxlum,$vidminlum):max-cll=$vidmaxcon,$vidMaxAvg" -preset $preset -tune $tune -pix_fmt yuv420p10le -crf $crf -fps_mode passthrough -async 0 -movflags +faststart "$vidDir\$vidNameSansExt.OUT.$vidExt"
		} else {
			Write-Host "'$vidExt' is not on the list. Choose from 'hevc' or 'mkv'" -ForegroundColor Red ;
		}
		
	}

	return "$vidDir\$vidNameSansExt.OUT"

}

function compile-SDR-video {
	param (
		[Parameter(Mandatory)]
		$vid,
		$vidExt,
		$vidWidth,
		$vidHeight,
		$tune,
		$preset,
		$vidAspectRatio,
		$vidNameSansExt,
		$vidDir
	)


	$acodec = "copy" ;
	if ($encodeFLAC) { $acodec = "flac" }


	$aspectRatioTop = [int]$aspectRatio.split(":")[0]; #width
	$aspectRatioBot = [int]$aspectRatio.split(":")[1]; #height
	$vidAspectRatioTop = [int]$vidAspectRatio.split(":")[0]; #width
	$vidAspectRatioBot = [int]$vidAspectRatio.split(":")[1]; #height

	$crf = 12 + (($compressionTier-1)*3);

	$bufWidth = $vidWidth ;
	$bufHeight = $vidHeight ;
	$scaleWidth = $vidWidth ;
	$scaleHeight = $vidHeight ;

	 # example being if we have a 1440x1080p video and want 16:9 AR, width = 1080 * 16/9
	 # alternatively, we have 1920x800p video and want 16:9 AR, height = 1920 * 9/16
	if ($vidAspectRatioBot -gt $vidAspectRatioTop) {
		Write-Host "`tAspect Ratio is Portrait" ;
		if ($favorCommercialDimensions) {
			if ($vidHeight -le 1080) {
				$scaleHeight = 1080
				$bufHeight = 1080
			} else {
				$scaleHeight = 2160
				$bufHeight = 2160
			}
		}
		$bufWidth = [Math]::Ceiling([int]$bufHeight*(${aspectRatioTop}/${aspectRatioBot})) ;
		$scaleWidth = -2 ;
	} else {
		Write-Host "`tAspect Ratio is Landscape or Square" ;
		if ($favorCommercialDimensions) {
			if ($vidWidth -le 1920) {
				$scaleWidth = 1920
				$bufWidth = 1920
			} else {
				$scaleWidth = 3840
				$bufWidth = 3840
			}
		}
		$bufHeight = [Math]::Ceiling([int]$bufWidth*(${aspectRatioBot}/${aspectRatioTop})) ;
		$scaleHeight = -2 ;
	}

	if (($bufWidth % 2) -ne 0) {
		$bufWidth++;
	}
	if (($bufHeight % 2) -ne 0) {
		$bufHeight++;
	}

	$frameRate = (ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nk=1:nw=1 $vid).Split("/") ;
	if ($frameRate.size -eq 1) {
		$frameRate = $frameRate[1];
	} elseif ($frameRate[1] -eq 0) {
		$frameRate = $frameRate[1];
	} else {
		$frameRate = $frameRate[0] + "/" + $frameRate[1];
	}


	$filter = "scale=${scaleWidth}:${scaleheight}:force_original_aspect_ratio=decrease,pad=${bufWidth}:${bufHeight}:(ow-iw)/2:(oh-ih)/2,setsar=1"
	if ($antialias) {
		$filter = -join("hqx=4,",$filter);
	}


	if ($restore) {


		if ($vidExt -eq "hevc") {
			nvencc64 --log-level warn -c hevc --avhw -i $vid --output-depth 10 --lossless --audio-copy  --videoformat ntsc --vpp-convolution3d "ythresh=1,cthresh=2,t_ythresh=2,t_cthresh=6" --vpp-deband "range=12,sample=2,thre_y=8,thre_cb=10,thre_cr=10,dither_y=2,dither_c=1,rand_each_frame" --vpp-libplacebo-deband "iterations=2,threshold=6,radius=8,grain_y=1,grain_c=0" -f hevc -o - --seek $seek --seekto $seekto | ffmpeg -r $framerate -colorspace bt709 -color_range tv -color_primaries bt709 -color_trc bt709 -y -i - -map 0:v:0 -map 0:a? -map 0:s? -c:v libx265 -c:a $acodec -c:s copy -filter:v $filter -preset $preset -tune $tune -pix_fmt yuv420p10le -crf $crf -fps_mode passthrough -async 0 -sws_flags lanczos -movflags +faststart "$vidDir\$vidNameSansExt.OUT.$vidExt"
		} elseif ($vidExt -eq "mkv") {
			nvencc64 --log-level warn -c hevc --avhw -i $vid --output-depth 10 --lossless --audio-copy  --videoformat ntsc --vpp-convolution3d "ythresh=1,cthresh=2,t_ythresh=2,t_cthresh=6" --vpp-libplacebo-deband "iterations=1,threshold=4,radius=8,grain_y=1,grain_c=0" -f nut -o - --seek $seek --seekto $seekto | ffmpeg -r "$framerate" -colorspace bt709 -color_range tv -color_primaries bt709 -color_trc bt709 -y -i - -ss $seek -i $vid -map 0:v:0 -map 1:a? -map 1:s? -map 1:t? -map_chapters 1 -c:v libx265 -c:a $acodec -c:s copy -filter:v $filter -preset $preset -tune $tune -pix_fmt yuv420p10le -crf $crf -fps_mode passthrough -async 0 -sws_flags lanczos -movflags +faststart "$vidDir\$vidNameSansExt.OUT.$vidExt"
		} else {
			Write-Host "'$vidExt' is not on the list. Choose from 'hevc' or 'mkv'" -ForegroundColor Red ;
			exit
		}

	} else {

		if ($vidExt -eq "hevc") {
			ffmpeg -colorspace bt709 -color_range tv -color_primaries bt709 -color_trc bt709 -y -i $vid -ss $seek -to $seekTo -map 0:v:0 -map 0:a? -map 0:s? -c:v libx265 -c:a $acodec -c:s copy -filter:v $filter -preset $preset -tune $tune -pix_fmt yuv420p10le -crf $crf -fps_mode passthrough -async 0 -sws_flags lanczos -movflags +faststart "$vidDir\$vidNameSansExt.OUT.$vidExt"
		} elseif ($vidExt -eq "mkv") {
			ffmpeg -ss $seek -colorspace bt709 -color_range tv -color_primaries bt709 -color_trc bt709 -y -i $vid -to $seekTo -map 0:v:0 -map 0:a? -map 0:s? -c:v libx265 -c:a $acodec -c:s copy -filter:v $filter -preset $preset -tune $tune -pix_fmt yuv420p10le -crf $crf -fps_mode passthrough -async 0 -sws_flags lanczos -movflags +faststart "$vidDir\$vidNameSansExt.OUT.$vidExt"
		} else {
			Write-Host "'$vidExt' is not on the list. Choose from 'hevc' or 'mkv'" -ForegroundColor Red ;
			exit
		}

	}

	return "$vidDir\$vidNameSansExt.OUT"

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


	ffmpeg -i $vid -map 0:v:0 -c:v copy -fps_mode passthrough -async 0 "$vidDir\$vidNameSansExt.hevc" $overwrite


	return "$vidDir\$vidNameSansExt"

}

function Format-TimeToSeconds {
	param ([Parameter(Mandatory)][String]$time)
	[double]$total = 0.0
	$timeSplit = $time -split ":"
	if ($timeSplit.length -eq 3) {
		$total += ([double]$timeSplit[0] * 3600)
		$total += ([double]$timeSplit[1] * 60)
		$total += ([double]$timeSplit[2])
	} elseif ($timeSplit.length -eq 2) {
		$total += ([double]$timeSplit[0] * 60)
		$total += ([double]$timeSplit[0])
	} else {
		$total += [double]$time
	}
	return $total
}

if ($h -eq $True -OR $help -eq $True) {
	Print-Help ;
}

if ($compressionTier -lt 1 -or $compressionTier -gt 5) {
	Write-Host "[ERROR] -storageTier $compressionTier is an invalid value." -ForegroundColor Red ;
	Write-Host "-storageTier needs to be an int between 1 (higher quality) and 5 (smaller size). Exiting..." -ForegroundColor Red ;
	Exit ;
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

if (($output -ne $Null) -AND ($output -match '^(\.{1,2}|[a-zA-Z]\:)[\\|/].*\..{0,4}$')) {
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


	if ($outputName -match '^(\.{1,2}|[a-zA-Z]\:)[\\|/].*\..+$') {
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
			New-Item -Path $outputName -ItemType Directory -Force ;
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



if ($seek -eq $null) {
	$seek = 0
} elseif (-NOT($seek -match "^(([0-9]{1,2}:)?([0-9]{1,2}):([0-9]{1,2})|[0-9]+)(\.[0-9]+)?$")) {
	Write-Host "'$seek' is an invalid value for -seek. Format as '##:##:##<.#*>'. The decimal, hours, and minutes are optional.`n" -ForegroundColor Red ;
	Print-Help ;
}

$subtractFromFinalTime = $false
if ($seekTo -eq $null) {
	$seekTo = "59:59:59.999"
} elseif ($seekTo -match "^-(([0-9]{1,2}:)?([0-9]{1,2}):([0-9]{1,2})|[0-9]+)(\.[0-9]+)?$") {
	$time = $seekTo.SubString(1) ;
	$timeSeconds = (Format-TimeToSeconds -time $time)
	$seekTo = [double]$timeSeconds
	$subtractFromFinalTime = $true
} elseif (-NOT($seekTo -match "^(([0-9]{1,2}:)?([0-9]{1,2}):([0-9]{1,2})|[0-9]+)(\.[0-9]+)?$")) {
	Write-Host "'$seekTo' is an invalid value for -seekTo. Format as '##:##:##<.#*>'. The decimal, hours, and minutes are optional." -ForegroundColor Red ;
	Write-Host "`tIf time is negative (IE. if the argument is preceded with '-', it will subtract from the end ('-##:##:##<.#*>' is acceptable).`n" -ForegroundColor Red ;
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
	$vidDuration = [double](ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 $vid) ;
	$vidAspectRatio = (ffprobe -v error -select_streams v:0 -show_entries stream=display_aspect_ratio -of default=nk=1:nw=1 $vid) ;

	if ($output -ne $Null) {
		if ($outputIsLeaf -eq $True) {
			$vidNameSansExt = $outputLeafSansExt ;
		} else {
			$vidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($vid) ;
		}
		$outputDir = $output ;
	} else {
		$vidNameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($vid) ;
		$outputDir = $vid.FullName | Split-Path
	}


	if (-NOT($overwrite) -AND ((Test-Path -literalPath "$outputDir/$vidNameSansExt.OUT.hevc" -pathType leaf) -OR (Test-Path -literalPath "$outputDir/$vidNameSansExt.OUT.mkv" -pathType leaf))) {
		Write-Host "[WARNING] '$outputDir/$vidNameSansExt.OUT.$vidExt' already exists. Skipping" -ForegroundColor Yellow ;
		continue ;
	}

	if($vidAspectRatio -eq "N/A" -OR $vidAspectRatio -eq $null ) {
		$vidAspectRatio = "${vidWidth}:${vidHeight}" ;
	}

	if ($noPadding) {
		$aspectRatio = $vidAspectRatio ;
	}



	if ($subtractFromFinalTime) {
		$seekTo = [String]([math]::round(($vidDuration - $seekTo),3))
	}


	Write-Host "Analyzing '$vidNameSansExt'..." -ForegroundColor Green ;
	Write-Host "Processing '$vidNameSansExt'..."

	if ($vidColorSp -eq "bt2020nc" -AND $vidColorTr -eq "smpte2084" -AND $vidColorPr -eq "bt2020" -AND -not($forceSDR)) {
			Write-Host "`t'$vidNameSansExt' is HDR" ;
			$vidRedX,$vidRedY,$vidGreenX,$vidGreenY,$vidBlueX,$vidBlueY,$vidWhPoX,$VidWhPoY,$vidminlum,$vidmaxlum,$vidmaxcon,$vidMaxAvg,$hasDynaHDR,$hasDoVi = Get-HDR-Color-Data $vid ;

			if ($HDRMaxCon -ne $NULL -AND $HDRMaxAvg -ne $NULL) {

				Write-Host "`t-HDRMaxCon and -HDRMaxAvg is provided. Inserting values: $HDRMaxCon & $HDRMaxAvg." ;
				$vidmaxCon = $HDRMaxCon ;
				$vidMaxAvg = $HDRMaxAvg ;

			}

			if ($hasDovi -eq $true) {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has Dolby Vison RPUs & HDR10+ SEIs" ;

					$DoviHDR10pVidPath = mux-x265-raw $vid -vidNameSansExt $vidNameSansExt -vidDir $outputDir
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.DV.hevc"

					dovi_tool -m 5 extract-rpu -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviHDR10pVidPath.DV.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"

					$outputVid = Compile-HDR-Video -vid "$DoviHDR10pVidPath.HDR10-only.hevc" -vidExt "hevc" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -tune $tune -preset $preset -vidWidth $vidWidth -vidHeight $vidHeight -aspectRatio $vidAspectRatio -vidNameSansExt $vidNameSansExt -vidDir $outputDir

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

					$DoviVidPath = mux-x265-raw $vid -vidNameSansExt $vidNameSansExt -vidDir $outputDir

					dovi_tool -m 5 extract-rpu -i "$DoviVidPath.hevc" -o "$DoviVidPath.DV-Data.bin"
					dovi_tool remove -i "$DoviVidPath.hevc" -o "$DoviVidPath.HDR10-only.hevc"

					$outputVid = Compile-HDR-Video -vid "$DoviVidPath.HDR10-only.hevc" -vidExt "hevc" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -tune $tune -preset $preset -vidWidth $vidWidth -vidHeight $vidHeight -vidAspectRatio $vidAspectRatio -vidNameSansExt $vidNameSansExt -vidDir $outputDir

					$outputDoviVid = "$outputVid.hevc".replace('HDR10-only','DV8')
					$outputDoviMKVVid = $outputDoviVid.replace('hevc','mkv')

					dovi_tool inject-rpu -i "$outputVid.hevc" -rpu-in "$DoviVidPath.DV-Data.bin" -o $outputDoviVid

					mkvmerge -o $outputDoviVid $outputDoviMKVVid

					Remove-Item "$DoviHDR10pVidPath.DV-Data.bin" -Force
					Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force
				}

			} else {
				if ($hasDynaHDR -eq $true) {
					Write-Host "`t'$vidNameSansExt' has HDR10+ SEIs" ;

					$DoviHDR10pVidPath = mux-x265-raw $vid -vidNameSansExt $vidNameSansExt -vidDir $outputDir
					hdr10plus_tool extract -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10p-Data.json"
					hdr10plus_tool remove -i "$DoviHDR10pVidPath.hevc" -o "$DoviHDR10pVidPath.HDR10-only.hevc"

					$outputVid = Compile-HDR-Video -vid "$DoviHDR10pVidPath.HDR10-only.hevc" -vidExt "hevc" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -tune $tune -preset $preset -vidWidth $vidWidth -vidHeight $vidHeight -vidAspectRatio $vidAspectRatio -vidNameSansExt $vidNameSansExt -vidDir $outputDir

					$outputDynaHDRVid = "$outputVid.hevc".replace('HDR10-only','HDR10p')

					hdr10plus_tool inject -i "$outputVid.hevc" -j "$DoviHDR10pVidPath.HDR10p-Data.json" -o $outputDynaHDRVid

					mkvmerge -o $outputDoviDynaHDRMKVVid $outputDynaHDRVid

					Remove-Item "$DoviHDR10pVidPath.HDR10p-Data.json" -Force
					Remove-Item "$DoviHDR10pVidPath.*.hevc" -Force

				} else {
					Write-Host "`t'$vidNameSansExt' has no Dynamic HDR metadata" ;

					Compile-HDR-Video -vid $vid -vidExt "mkv" -vidRedX $vidRedX -vidRedY $vidRedY -vidGreenX $vidGreenX -vidGreenY $vidGreenY -vidBlueX $vidBlueX -vidBlueY $vidBlueY -vidWhPoX $vidWhPoX -VidWhPoY $VidWhPoY -vidminlum $vidminlum -vidmaxlum $vidmaxlum -vidmaxcon $vidmaxcon -vidMaxAvg $vidMaxAvg -tune $tune -preset $preset -vidWidth $vidWidth -vidHeight $vidHeight -vidAspectRatio $vidAspectRatio -vidNameSansExt $vidNameSansExt -vidDir $outputDir
				}
			}
		}
	else {
			Write-Host "`t'$vidNameSansExt' is SDR or SDR is forced" ;
			Compile-SDR-Video -vid $vid -vidExt "mkv" -tune $tune -preset $preset -vidWidth $vidWidth -vidHeight $vidHeight -vidAspectRatio $vidAspectRatio -vidNameSansExt $vidNameSansExt -vidDir $outputDir
	}
	Write-Host "------------"
}

