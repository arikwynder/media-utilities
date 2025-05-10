param(
    $path=".\",
    [switch]$skipStereo
)

foreach ($file in Get-Childitem -path $path -recurse -depth 0 -file -include *.thd,*.dts,*.eac3,*.ac3,*.m4a,*.flac,*.wav ) {

    $directoryName = $file.directoryname ;
    $nameSansExt = [System.IO.Path]::GetFileNameWithoutExtension($file) ;
    $ext = [System.IO.Path]::GetExtension($file) ;
    $channels = (ffprobe -v error -select_streams a -show_entries stream=channels -of default=nk=1:nw=1 $file) ;

    if (-NOT($skipStereo) -OR $channels -ne 2) {
        if(-Not(Test-Path "$path\${channels}ch" -pathType container)) {
            New-Item "$path\${channels}ch" -itemtype directory -force;
        }

        if ($ext -eq "wav") {
            Move-Item -literalpath $i -destination "$path\${channel}ch\$j.wav"
        } else {
            ffmpeg -i $file -c:a pcm_s24le -rf64 auto -async 0 "$path\${channels}ch\$j.wav"
        }    
    }

}