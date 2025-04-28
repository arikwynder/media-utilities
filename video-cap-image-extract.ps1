param(
	$name="",
	$chapter = "",
	$seek = "00:00:00.000",
	$to = "60:00:00",
	$vidFile="",
	$outDir="L:\Art\image sequences\nvencc64-ffmpeg",
	$outRes="3840x-2",
	$inFrameRate="24000/1001",
	$sourcePeak="1000",
	$crop="0,280,0,280"
)

$path= "$outDir\$name\$chapter" ;
mkdir $path ;
nvencc64 --log-level quiet --avhw -i $vidFile --seek $seek --seekto $to -c hevc --output-depth 10 --lossless --colorrange auto --videoformat ntsc --colormatrix auto --colorprim auto --transfer auto --chromaloc auto --max-cll copy --master-display copy --atc-sei auto --crop $crop --vpp-colorspace "hdr2sdr=bt2390,desat_strength=0.55,desat_exp=1.75,source_peak=$sourcePeak" --output-res $outRes --vpp-resize "algo=super" --vpp-convolution3d "ythresh=0,cthresh=2,t_ythresh=1,t_cthresh=3" --vpp-edgelevel "strength=2,threshold=30,black=2,white=1" --vpp-deband "range=10,thre_y=5,thre_cb=3,thre_cr=3,dither_y=10,dither_c=4,rand_each_frame" -f hevc -o - | ffmpeg -hide_banner -r $inFrameRate -i - -map 0:v:0 -c:v tiff -pix_fmt rgb32 -fps_mode passthrough -compression_algo deflate "$path\%06d.tif" ;
video-cap-rename-timecodes -startPath $path -movie $name -chapter $chapter -startTime $seek ;