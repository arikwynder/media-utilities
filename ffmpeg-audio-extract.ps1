param(
	[string]$path='.\',
	[string]$include="*.mkv",
	[string]$exclude="*.hevc",
	[string]$outDir="",
	[string]$codec="copy",
	[string]$specifiedLanguages="",
	[string]$maxChar=50,
	[switch]$firstTrackOnly,
	[switch]$losslessOnly,
	[switch]$allowLossyIfSingleTrack,
	#[switch]$allowLossyIfNoLossless, -> TO DO: If there is no lossless track in the file, the comparisons should run anyway
                                                # Complication would require compiling list of tracks before running through it. Possible, but will take more memory.
	[switch]$multichannelOnly,
	[switch]$rawFormat,
	[switch]$favorStored,
	[switch]$overwrite,
	[Alias('h')][switch]$help,
	[Alias('l')][switch]$langHelp
) # -> TO DO: a few other methods to possibly implement
#


# functions
function Show-Help {
    Write-Host "Usage: ./ffmpeg-audio-extract.ps1 [parameters]" -ForegroundColor Green
    Write-Host "Parameters:"
    Write-Host "`t-path [string] (default: '.\')"
    Write-Host "`t`tSpecifies the directory path where the script will search for video files."
    Write-Host ""
    Write-Host "`t-include [string] (default: '*.mkv')"
    Write-Host "`t`tDefines the file types to include in the search (e.g., '*.mp4', '*.mkv')."
    Write-Host ""
    Write-Host "`t-exclude [string] (default: '*.hevc')"
    Write-Host "`t`tSpecifies the file types to exclude from the search."
    Write-Host ""
    Write-Host "`t-outDir [string] (default: '')"
    Write-Host "`t`tSets the output directory for processed files. If not specified, the current directory will be used."
    Write-Host ""
    Write-Host "`t-codec [string] (default: 'copy')"
    Write-Host "`t`tDetermines the codec to use for audio processing. Use 'copy' to retain the original codec."
    Write-Host ""
    Write-Host "`t-specifiedLanguages [string] (default: '')"
    Write-Host "`t`tSpecifies the languages to filter tracks by, using ISO 639-3 codes (e.g., 'eng', 'jpn')."
    Write-Host "`t`tMultiple languages can be separated by commas."
    Write-Host "`t`tUse '-langHelp' for examples."
    Write-Host ""
    Write-Host "`t-maxChar [string] (default: 50)"
    Write-Host "`t`tLimits the maximum length of output file names. Useful for avoiding overly long file names."
    Write-Host ""
    Write-Host "`t-firstTrackOnly [switch]"
    Write-Host "`t`tProcesses only the first audio track from each file if enabled."
    Write-Host ""
    Write-Host "`t-losslessOnly [switch]"
    Write-Host "`t`tEnsures only lossless audio tracks are processed if enabled."
    Write-Host ""
    Write-Host "`t-allowLossyIfSingleTrack [switch]"
    Write-Host "`t`tAllows lossy tracks to be processed if the file contains only one audio track."
    Write-Host ""
    Write-Host "`t-multichannelOnly [switch]"
    Write-Host "`t`tProcesses only multichannel audio tracks if enabled."
    Write-Host ""
    Write-Host "`t-rawFormat [switch]"
    Write-Host "`t`tOutputs tracks in their raw format (e.g., '.wav' for PCM) if enabled."
    Write-Host ""
    Write-Host "`t-favorStored [switch]"
    Write-Host "`t`tIf enabled, gives preference to tracks already stored as the 'best track.'"
    Write-Host ""
    Write-Host "`t-overwrite [switch]"
    Write-Host "`t`tOverwrites existing files in the output directory if enabled."
    Write-Host ""
    Write-Host "`t-help [switch]"
    Write-Host "`t`tPrints this help message."
    Write-Host ""
    Write-Host "`t-h [switch]"
    Write-Host "`t`tAlias for '-help'"
    Write-Host ""
    Write-Host "`t-langHelp [switch]"
    Write-Host "`t`tPrints language help for '-specifiedLanguages'"
    Write-Host ""
    Write-Host "`t-l [switch]"
    Write-Host "`t`tAlias for '-langHelp'"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "`t./ffmpeg-audio-extract.ps1 -path 'C:\Videos' -include '*.mp4' -outDir 'C:\Output' -losslessOnly"
    Write-Host "`t./ffmpeg-audio-extract.ps1 -path 'C:\Movies' -specifiedLanguages 'eng,jpn' -rawFormat -overwrite"
    Write-Host ""
    exit
}

function Show-LangHelp {
    # TO DO: implement a hash table of all language codes to be able to do a quick search
    $langHelp = @(
        "English -> 'eng'",
        "Japanese -> 'jpn'",
        "Spanish -> 'spa'",
        "French -> 'fre'",
        "Korean -> 'kor'"
    )
    Write-Host "Specified Languages must be written in ISO-639-3 format. For example: " -foregroundColor DarkYellow
    foreach ($lang in $langHelp) {
        Write-Host "`t" -noNewLine ; Write-Host "$lang" -foregroundColor DarkYellow
    }
    Write-Host "For further codes: https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes" -foregroundColor DarkYellow
    exit

}

function Get-TrackPriority {
    param (
        [Parameter(Mandatory=$true)][string]$profile,
        [Parameter(Mandatory=$true)][int]$channels,
        [Parameter(Mandatory=$true)][string]$codec,
        [Parameter(Mandatory=$true)][string]$sampleFormat,
        [Parameter(Mandatory=$true)][string]$sampleRate
    )

    # Helper function to determine sample format priority
    function Get-SampleFormatPriority {
        param ([Parameter(Mandatory=$true)][string]$sampleFormat)

        # Remove any trailing 'p' from the sample format
        $cleanFormat = $sampleFormat.TrimEnd('p')

        switch ($cleanFormat) {
            "s64" { return 100000 }
            "s32" { return 10000 }
            "s24" { return 9000 }
            "s16" { return 8000 }
            "fltp" { return 1 }
            default { return 0 }
        }
    }

    # Helper function to determine sample rate priority
    function Get-SampleRatePriority {
        param ([Parameter(Mandatory=$true)][string]$sampleRate)

        # return a truncated sample rate divided by 1000 hertz
        return [int]$sampleRate/1000
    }

    # Assign priority based on profile and channel configuration
    if ($codec -eq "copy") {
        switch ($profile) {
            "Dolby TrueHD + Dolby Atmos" { return 21 }  # Highest priority for Dolby Atmos
            "DTS-HD MA + DTS:X" { return 20 }           # Next priority for DTS:X
            "Dolby TrueHD" { return 21 }  # Next priority for Dolby TrueHD
            "DTS-HD MA + DTS:X" { return 20 }           # Next priority for DTS:X
            "Dolby Digital Plus + Dolby Atmos" { return 19 } # Lossy with Atmos
            default {
                $channelsPriority = $channels
                $sampleFormatPriority = Get-SampleFormatPriority -sampleFormat $sampleFormat
                $sampleRatePriority = Get-SampleRatePriority -sampleRate $sampleRate
                return [int]($channelsPriority * 1000 + $sampleFormatPriority + $sampleRatePriority)
            }
        }
    } else {
            $channelsPriority = $channels
            $sampleFormatPriority = Get-SampleFormatPriority -sampleFormat $sampleFormat
            $sampleRatePriority = Get-SampleRatePriority -sampleRate $sampleRate
            return [int]($channelsPriority * 1000 + $sampleFormatPriority + $sampleRatePriority)
    }
}

function Get-RawFormat {
    param ([Parameter(Mandatory=$true)][string]$codec)

    #Return the raw format per the intended final-used codec
    switch -Wildcard ($codec) {
        "truehd" {return "truehd"}
        "eac3" {return "eac3"}
        "ac3" {return "ac3"}
        "dts" {return "dts"}
        "flac" {return "flac"}
        "alac" {return "m4a"}
        "aac" {return "m4a"}
        "opus" {return "opus"}
        "pcm*" {return "wav"}
        default { Write-Host "rawFormat switch applied, but unknown output codec. Using '.mka'..." -foregroundColor red ; return "mka" }
    }
}

function BestTracks-SetTrack {
    param (
        [Parameter(Mandatory=$true)][string]$language,
        [Parameter(Mandatory=$true)][string]$title,
        [Parameter(Mandatory=$true)][int]$trackNum,
        [Parameter(Mandatory=$true)][string]$profile,
        [Parameter(Mandatory=$true)][int]$channels,
        [Parameter(Mandatory=$true)][string]$codec,
        [Parameter(Mandatory=$true)][string]$originalCodec,
        [Parameter(Mandatory=$true)][string]$sampleFormat,
        [Parameter(Mandatory=$true)][int]$sampleRate,
        [Parameter(Mandatory=$true)][string]$extension
    )


     # Update the best track for this language
     $global:bestTracks[$language] = @{
        track = $trackNum
        title = $title
        profile = $profile
        channels = $channels
        sampleFormat = $sampleFormat
        sampleRate = $sampleRate
        codec = $codec
        originalCodec = $originalCodec
        extension = $extension
        priority = (Get-TrackPriority -profile $profile -codec $codec -channels $channels -sampleFormat $sampleFormat -sampleRate $sampleRate)
     }
}

function AllTracks-AddTrack {
	param (
        [Parameter(Mandatory=$true)][string]$language,
        [Parameter(Mandatory=$true)][string]$title,
        [Parameter(Mandatory=$true)][int]$trackNum,
        [Parameter(Mandatory=$true)][string]$profile,
        [Parameter(Mandatory=$true)][int]$channels,
        [Parameter(Mandatory=$true)][string]$codec,
        [Parameter(Mandatory=$true)][string]$originalCodec,
        [Parameter(Mandatory=$true)][string]$sampleFormat,
        [Parameter(Mandatory=$true)][int]$sampleRate,
        [Parameter(Mandatory=$true)][string]$extension
    )

     # Update the best track for this language
     $global:allTracks[$global:AllTracksIterate] = @{
        track = $trackNum
		language = $language
        title = $title
        profile = $profile
        channels = $channels
        sampleFormat = $sampleFormat
        sampleRate = $sampleRate
        codec = $codec
        originalCodec = $originalCodec
        extension = $extension
        priority = (Get-TrackPriority -profile $profile -codec $codec -channels $channels -sampleFormat $sampleFormat -sampleRate $sampleRate)
     }
	$global:AllTracksIterate++ ;
}

function BestTracks-Print {


    foreach ($key in $global:bestTracks.Keys) {

        $language = $key
        switch($language) {
            "eng" { $language = "English" }
            "jpn" { $language = "Japanese" }
            "chi" { $language = "Chinese" }
            "kor" { $language = "Korean" }
            "spa" { $language = "Spanish" }
            "ita" { $language = "Italian" }
            default { $language = $language.toUpper() }
        }

        Write-Host $global:bestTracks.$key.title -noNewLine -foregroundColor cyan ; Write-Host " [$language]" -foregroundColor cyan
        Write-Host "`tTrack Number:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:bestTracks.$key.track -foregroundColor cyan
        Write-Host "`tPriority:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:bestTracks.$key.priority -foregroundColor cyan
        Write-Host "`tProfile:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:bestTracks.$key.profile -foregroundColor cyan
        Write-Host "`tCodec:`t`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:bestTracks.$key.originalCodec -foregroundColor cyan
        Write-Host "`tChannels:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:bestTracks.$key.channels -foregroundColor cyan
        Write-Host "`tSample Format:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:bestTracks.$key.sampleFormat -foregroundColor cyan
        Write-Host "`tSample Rate:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:bestTracks.$key.sampleRate -foregroundColor cyan
        Write-Host "`n"
    }

}

function AllTracks-Print {


    foreach ($key in $global:allTracks.Keys) {

		$language = $global:allTracks.$key.language

        Write-Host $global:allTracks.$key.title -noNewLine -foregroundColor cyan ; Write-Host " [$language]" -foregroundColor cyan
        Write-Host "`tTrack Number:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:allTracks.$key.track -foregroundColor cyan
        Write-Host "`tPriority:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:allTracks.$key.priority -foregroundColor cyan
        Write-Host "`tProfile:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:allTracks.$key.profile -foregroundColor cyan
        Write-Host "`tCodec:`t`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:allTracks.$key.originalCodec -foregroundColor cyan
        Write-Host "`tChannels:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:allTracks.$key.channels -foregroundColor cyan
        Write-Host "`tSample Format:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:allTracks.$key.sampleFormat -foregroundColor cyan
        Write-Host "`tSample Rate:`t`t" -noNewLine -foregroundColor cyan ; Write-Host $global:allTracks.$key.sampleRate -foregroundColor cyan
        Write-Host "`n"
    }

}

function BestTracks-Compile {

    param( [Parameter(Mandatory=$true)][string]$outDir )

    foreach ($key in $global:bestTracks.Keys) {

        # set variables to compile output for track
        $language = $global:bestTracks.$key
        $track = $global:bestTracks.$key.track
        $origCodec = $global:bestTracks.$key.originalCodec
        $channels = $global:bestTracks.$key.channels
        $sampFmt = $global:bestTracks.$key.sampleFormat
        $sampRate = $global:bestTracks.$key.sampleRate
        $extension = $global:bestTracks.$key.extension

        # concatanate on new parameters
        if ( $extension -eq "wav" ) {
            $global:ffParameters += "-map 0:a:$track -c:a $codec -rf64 auto -async 0 '$outDir\$name.track_$track.$origCodec.${channels}ch.$sampFmt.${sampRate}Hz.$lang.$extension' " ;
        } else {
            $global:ffParameters += "-map 0:a:$track -c:a $codec -async 0 '$outDir\$name.track_$track.$origCodec.${channels}ch.$sampFmt.${sampRate}Hz.$lang.$extension' " ;
        }

    }

}

# global variables
$global:allTracks = @{} ;
$global:allTracksIterate = 0 ;
$global:bestTracks = @{} ;
$global:ffParameters = "" ;
$global:channelLayoutExclusions = @("mono","stereo","2.1","3.0","3.1","binaural","downmix") ;
$global:languageCodes = @( "aar",  "abk",  "ace",  "ach",  "ada",  "ady",  "afa",  "afh",  "afr",  "ain",  "aka",  "akk",  "alb",  "ale",  "alg",  "alt",  "amh",  "ang",  "anp",  "apa",  "ara",
                            "arc",  "arg",  "arm",  "arn",  "arp",  "art",  "arw",  "asm",  "ast",  "ath",  "aus",  "ava",  "ave",  "awa",  "aym",  "aze",  "bad",  "bai",  "bak",  "bal",  "bam",
                            "ban",  "baq",  "bas",  "bat",  "bej",  "bel",  "bem",  "ben",  "ber",  "bho",  "bih",  "bik",  "bin",  "bis",  "bla",  "bnt",  "bos",  "bra",  "bre",  "btk",  "bua",
                            "bug",  "bul",  "bur",  "byn",  "cad",  "cai",  "car",  "cat",  "cau",  "ceb",  "cel",  "cha",  "chb",  "che",  "chg",  "chi",  "chk",  "chm",  "chn",  "cho",  "chp",
                            "chr",  "chu",  "chv",  "chy",  "cmc",  "cnr",  "cop",  "cor",  "cos",  "cpe",  "cpf",  "cpp",  "cre",  "crh",  "crp",  "csb",  "cus",  "cze",  "dak",  "dan",  "dar",  "day",
                            "del",  "den",  "dgr",  "din",  "div",  "doi",  "dra",  "dsb",  "dua",  "dum",  "dut",  "dyu",  "dzo",  "efi",  "egy",  "eka",  "elx",  "eng",  "enm",  "epo",  "est",  "ewe",
                            "ewo",  "fan",  "fao",  "fat",  "fij",  "fil",  "fin",  "fiu",  "fon",  "fre",  "frm",  "fro",  "frr",  "frs",  "fry",  "ful",  "fur",  "gaa",  "gay",  "gba",  "gem",  "geo",
                            "ger",  "gez",  "gil",  "gla",  "gle",  "glg",  "glv",  "gmh",  "goh",  "gon",  "gor",  "got",  "grb",  "grc",  "gre",  "grn",  "gsw",  "guj",  "gwi",  "hai",  "hat",  "hau",
                            "haw",  "heb",  "her",  "hil",  "him",  "hin",  "hit",  "hmn",  "hmo",  "hrv",  "hsb",  "hun",  "hup",  "iba",  "ibo",  "ice",  "ido",  "iii",  "ijo",  "iku",  "ile",  "ilo",  "ina",  "inc",  "ind",
                            "ine",  "inh",  "ipk",  "ira",  "iro",  "ita",  "jav",  "jbo",  "jpn",  "jpr",  "jrb",  "kaa",  "kab",  "kac",  "kal",  "kam",  "kan",  "kar",  "kas",  "kau",  "kaw",  "kaz",  "kbd",  "kha",  "khi",
                            "khm",  "kho",  "kik",  "kin",  "kir",  "kmb",  "kok",  "kom",  "kon",  "kor",  "kos",  "kpe",  "krc",  "krl",  "kro",  "kru",  "kua",  "kum",  "kur",  "kut",  "lad",  "lah",  "lam",  "lao",  "lat",
                            "lav",  "lez",  "lim",  "lin",  "lit",  "lol",  "loz",  "ltz",  "lua",  "lub",  "lug",  "lui",  "lun",  "luo",  "lus",  "mac",  "mad",  "mag",  "mah",  "mai",  "mak",  "mal",  "man",  "mao",  "map",
                            "mar",  "mas",  "may",  "mdf",  "mdr",  "men",  "mga",  "mic",  "min",  "mis",  "mkh",  "mlg",  "mlt",  "mnc",  "mni",  "mno",  "moh",  "mon",  "mos",  "mul",  "mun",  "mus",  "mwl",  "mwr",  "myn",
                            "myv",  "nah",  "nai",  "nap",  "nau",  "nav",  "nbl",  "nde",  "ndo",  "nds",  "nep",  "new",  "nia",  "nic",  "niu",  "nno",  "nob",  "nog",  "non",  "nor",  "nqo",  "nso",  "nub",  "nwc",  "nya",
                            "nym",  "nyn",  "nyo",  "nzi",  "oci",  "oji",  "ori",  "orm",  "osa",  "oss",  "ota",  "oto",  "paa",  "pag",  "pal",  "pam",  "pan",  "pap",  "pau",  "peo",  "per",  "phi",  "phn",  "pli",  "pol",
                            "pon",  "por",  "pra",  "pro",  "pus",  "qaa-qtz",  "que",  "raj",  "rap",  "rar",  "roa",  "roh",  "rom",  "rum",  "run",  "rup",  "rus",  "sad",  "sag",  "sah",  "sai",  "sal",  "sam",  "san",  "sas",
                            "sat",  "scn",  "sco",  "sel",  "sem",  "sga",  "sgn",  "shn",  "sid",  "sin",  "sio",  "sit",  "sla",  "slo",  "slv",  "sma",  "sme",  "smi",  "smj",  "smn",  "smo",  "sms",  "sna",  "snd",  "snk",  "sog",
                            "som",  "son",  "sot",  "spa",  "srd",  "srn",  "srp",  "srr",  "ssa",  "ssw",  "suk",  "sun",  "sus",  "sux",  "swa",  "swe",  "syc",  "syr",  "tah",  "tai",  "tam",  "tat",  "tel",  "tem",  "ter",  "tet",
                            "tgk",  "tgl",  "tha",  "tib",  "tig",  "tir",  "tiv",  "tkl",  "tlh",  "tli",  "tmh",  "tog",  "ton",  "tpi",  "tsi",  "tsn",  "tso",  "tuk",  "tum",  "tup",  "tur",  "tut",  "tvl",  "twi",  "tyv",  "udm",
                            "uga",  "uig",  "ukr",  "umb",  "und",  "urd",  "uzb",  "vai",  "ven",  "vie",  "vol",  "vot",  "wak",  "wal",  "war",  "was",  "wel",  "wen",  "wln",  "wol",  "xal",  "xho",  "yao",  "yap",  "yid",  "yor",
                            "ypk",  "zap",  "zbl",  "zen",  "zgh",  "zha",  "znd",  "zul",  "zun",  "zxx",  "zza") ;
$global:languageFilter = -split $specifiedLanguages ;

# help based function checks
if ($help) {Show-Help}
if ($langHelp) {Show-LangHelp}

# argument-based conditional variables
$audioGrab=1
if (-NOT(Test-Path -literalPath $outDir -type container) -AND ($outDir.length -ne 0)) {
	New-Item -path $outDir -itemType directory -force ;
}

$overwriteStr = "-n"
if ($overwrite) {
	$overwriteStr = "-y"
}

$processAllLanguages = $true
if ($specifiedLanguages.length -gt 0 -AND $specifiedLanguages.length -lt 4) {
    for ($lang in $global:languageFilter) {
        if ($global:languageCodes -notcontains $lang.toLower()) {
            Write-Host "[ERROR] Specified Language '$lang' does not exist in ISO-639 list." -foregroundColor red
            Print-LangCodes() ;
            Write-Host "Exiting..." -foregroundColor red
            exit
        }
    }
    $processAllLanguages = $false
} elseif ($specifiedLanguages.length -gt 3) {
    Write-Host "[ERROR] One or more of the specified languages does not match the length requirements." -foregroundColor red
    Print-LangCodes() ;
    Write-Host "Exiting..." -foregroundColor red
    exit

}

# main loop
foreach ($vid in Get-ChildItem -Path $path -Recurse -Include $include -exclude $exclude ) {

    $global:bestTracks.Clear() ;
	$global:ffParameters = "" ;
	$global:allTracksIterate = 0 ;

	$name = [System.IO.Path]::GetFileNameWithoutExtension($vid);
	if ($name.length -gt $maxChar) {
		$name = $name.subString(0,$maxChar);
	}
	if (-not($firstTrackOnly)) { $audioGrab = (ffprobe -v error -show_entries stream=codec_type -of default=nk=1:nw=1 $vid | Select-String audio).count }
	if ($outDir.length -eq 0) {
		$outDir = $vid.DirectoryName ;
	}
	for ($aud = 0 ; $aud -lt $audioGrab ; $aud++) {
	   try {
    		$channels = [int](ffprobe -hide_banner -loglevel quiet -select_streams a:$aud -show_entries stream=channels -of default=nw=1:nk=1 $vid) ;
    		$channelLayout = [string](ffprobe -hide_banner -loglevel quiet -select_streams a:$aud -show_entries stream=channel_layout -of default=nw=1:nk=1 $vid) ;
    		$origCodec = ffprobe -hide_banner -loglevel quiet -select_streams a:$aud -show_entries stream=codec_name -of default=nw=1:nk=1 $vid ;
    		$sampFmt = ffprobe -hide_banner -loglevel quiet -select_streams a:$aud -show_entries stream=sample_fmt -of default=nw=1:nk=1 $vid ;
    		$sampRate = [int](ffprobe -hide_banner -loglevel quiet -select_streams a:$aud -show_entries stream=sample_rate -of default=nw=1:nk=1 $vid) ;
    		$lang = ffprobe -hide_banner -loglevel quiet -select_streams a:$aud -show_entries stream_tags=language -of default=nw=1:nk=1 $vid ;
    		$metaTitle = ffprobe -hide_banner -loglevel quiet -select_streams a:$aud -show_entries stream_tags=title -of default=nw=1:nk=1 $vid ;
    		$profile = ffprobe -hide_banner -loglevel quiet -select_streams a:$aud -show_entries stream=profile -of default=nw=1:nk=1 $vid ;
        catch {
            Write-Host "[ERROR] Error retrieving metadata from track $aud in file: $vid" -ForegroundColor Red
            continue
        }

		$extension = "mka" ;


		if ($rawFormat) {
		  if ($codec -eq "copy") { $extension = (Get-RawFormat -codec $origCodec) }
		  else { $extension = (Get-RawFormat -codec $codec) }
		}

        # Test selected audio tracks for whether they are worth extracting based on given parameters
		if ($firstTrackOnly) {
			if ($extension -eq "wav") {
				$global:ffParameters += "-map 0:a:$aud -c:a $codec -rf64 auto -async 0 '$outDir\$name.track_$aud.$origCodec.${channels}ch.$sampFmt.$lang.$extension'" ;
			} else {
				$global:ffParameters += "-map 0:a:$aud -c:a $codec -async 0 '$outDir\$name.track_$aud.$origCodec.${channels}ch.$sampFmt.$lang.$extension'" ;
			}
		} else {
			AllTracks-AddTrack -language $lang -title $metaTitle -trackNum $aud -profile $profile -channels $channels -codec $codec -originalCodec $origCodec -sampleFormat $sampFmt -sampleRate $sampRate -extension $extension

			# COMPARING TRACKS
			if (-not $global:bestTracks.ContainsKey($lang) -AND (
                    -NOT (
                        $losslessOnly -AND
                        ($sampFmt -eq "fltp") -AND
                        (-NOT ($allowLossyIfSingleTrack -AND ($audioGrab -eq 1)))
                    ) -AND
                    -NOT (
                        $multichannelOnly -AND
                        ($global:channelLayoutExclusions -notcontains $channelLayout.toLower())
                    ) -AND
                    -NOT (
                        $processAllLanguages -AND
                        ($global:languageFilter -notcontains $lang.toLower())
                    )
                ) {
                # Update the best track for this language
                BestTracks-SetTrack -language $lang -title $metaTitle -trackNum $aud -profile $profile -channels $channels -codec $codec -originalCodec $origCodec -sampleFormat $sampFmt -sampleRate $sampRate -extension $extension
            } elseif (
                    -NOT (
                        $losslessOnly -AND
                        ($sampFmt -eq "fltp") -AND
                        (-NOT ($allowLossyIfSingleTrack -AND ($audioGrab -eq 1)))
                    ) -AND
                    -NOT (
                        $multichannelOnly -AND
                        ($global:channelLayoutExclusions -notcontains $channelLayout.toLower())
                    ) -AND
                    -NOT (
                        $processAllLanguages -AND
                        ($global:languageFilter -notcontains $lang.toLower())
                    )
                    ) {
                $currentPriority = (Get-TrackPriority -profile $profile -channels $channels -codec $codec -sampleFormat $sampFmt -sampleRate $sampRate)
                if ($currentPriority -gt $global:bestTracks[$lang].priority) {
                    BestTracks-SetTrack -language $lang -title $metaTitle -trackNum $aud -profile $profile -channels $channels -codec $codec -originalCodec $origCodec -sampleFormat $sampFmt -sampleRate $sampRate -extension $extension
                } elseif (-not($favorStored) -AND ($currentPriority -eq $global:bestTracks[$lang].priority)) {
                    Write-Host "[-favorStored not set] Currently scanned track has the same priority and language of the stored track." -ForegroundColor magenta

                    # print out information of stored track
                    Write-Host "`nStored Track [$lang]:" -ForegroundColor magenta
                    Write-Host "`tTrack Number:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $global:bestTracks[$lang].track -foregroundColor magenta
                    Write-Host "`tTitle:`t`t`t" -noNewLine -foregroundColor magenta ; Write-Host $global:bestTracks[$lang].title -foregroundColor magenta
                    Write-Host "`tPriority:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $global:bestTracks[$lang].priority -foregroundColor magenta
                    Write-Host "`tProfile:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $global:bestTracks[$lang].profile -foregroundColor magenta
                    Write-Host "`tCodec:`t`t`t" -noNewLine -foregroundColor magenta ; Write-Host $global:bestTracks[$lang].originalCodec -foregroundColor magenta
                    Write-Host "`tChannels:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $global:bestTracks[$lang].channels -foregroundColor magenta
                    Write-Host "`tSample Format:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $global:bestTracks[$lang].sampleFormat -foregroundColor magenta
                    Write-Host "`tSample Rate:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $global:bestTracks[$lang].sampleRate -foregroundColor magenta

                    # print out information of current track
                    Write-Host "`n`nCurrent Track [$lang]:" -ForegroundColor magenta
                    Write-Host "`tTrack Number:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $aud -foregroundColor magenta
                    Write-Host "`tTitle:`t`t`t" -noNewLine -foregroundColor magenta ; Write-Host $metaTitle -foregroundColor magenta
                    Write-Host "`tPriority:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $currentPriority -foregroundColor magenta
                    Write-Host "`tProfile:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $profile -foregroundColor magenta
                    Write-Host "`tCodec:`t`t`t" -noNewLine -foregroundColor magenta ; Write-Host $origCodec -foregroundColor magenta
                    Write-Host "`tChannels:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $channels -foregroundColor magenta
                    Write-Host "`tSample Format:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $sampFmt -foregroundColor magenta
                    Write-Host "`tSample Rate:`t`t" -noNewLine -foregroundColor magenta ; Write-Host $sampRate -foregroundColor magenta

                    Write-Host "`n`nChoose which to keep:" -ForegroundColor magenta
                    Write-Host "`t(1) Stored Track" -ForegroundColor magenta
                    Write-Host "`t(2) Current Track" -ForegroundColor magenta
                    $choice = Read-Host "Selection: "

                    switch ($choice) {
                        1 { Write-Host "`n`nNot overwriting..." -ForegroundColor green }
                        2 {
                            Write-Host "`n`nStoring current track..." -ForegroundColor green
                            BestTracks-SetTrack -language $lang -title $metaTitle -trackNum $aud -profile $profile -channels $channels -codec $codec -originalCodec $origCodec -sampleFormat $sampFmt -sampleRate $sampRate -extension $extension
                        }
                    }

                } else {
                    # Nothing to do...
                }
            } else {
    # Final else to handle edge cases
    Write-Host "No valid track for language [$lang] or track does not meet lossless criteria." -ForegroundColor yellow
            }
# 			    if (
# 			        $allowLossyIfSingleTrack -and $audioGrab -eq 1 -and ($sampFmt -match "s[1-3][2-6](p?)") -and -NOT($multichannelOnly)
# 			    ) -or
# 			    (
# 			        (-NOT($losslessOnly) -or ($sampFmt -match "s[1-3][2-6](p?)")) -and
# 			        (-NOT($multichannelOnly) -or ([int]$channels -gt 2))
# 			    )
# 		) {
#
 		}
	}

	if ($global:bestTracks.length -gt 0) { BestTracks-Compile -outDir $outDir }

	if ($global:ffParameters.length -ne 0) {
	   iex "ffmpeg $overwriteStr -i '$vid' $global:ffParameters"
    } else {
        Write-Host "No suitable audio tracks found for processing."
    }

}