#!/usr/bin/env bash
# Render a captioned release video from verified real-device captures.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input_dir="${1:-${repo_dir}/captures/v1.0.0-beta.1/raw}"
output_dir="${2:-${repo_dir}/captures/v1.0.0-beta.1/final}"
exact_dir="${input_dir}/exact"
font_regular="${repo_dir}/assets/fonts/Lexend-Regular.ttf"
font_bold="${repo_dir}/assets/fonts/Lexend-Bold.ttf"
work_dir="$(mktemp -d -p /tmp edgehub-video.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT INT TERM

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required" >&2; exit 2; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe is required" >&2; exit 2; }
install -d "$output_dir" "$work_dir/cards" "$work_dir/clips"

portrait="${exact_dir}/edgehub-v1.0.0-beta.1-hub-portrait-hero-01.png"
landscape="${exact_dir}/edgehub-v1.0.0-beta.1-hub-landscape-hero-01.png"
manager_base="${input_dir}/manager-action-screens-tab.png"
manager_screens="${input_dir}/manager-action-after-add-screen.png"
manager_portrait="${input_dir}/reflection-04-orient-portrait.png"
manager_landscape="${input_dir}/reflection-05-orient-landscape.png"
manager_light="${input_dir}/reflection-02-theme-light.png"
manager_matrix="${input_dir}/reflection-03-theme-matrix.png"

for source in "$portrait" "$landscape" "$manager_base" "$manager_screens" \
              "$manager_portrait" "$manager_landscape" "$manager_light" \
              "$manager_matrix" "$font_regular" "$font_bold"; do
    [ -s "$source" ] || { echo "missing video input: $source" >&2; exit 2; }
done

card() {
    local source="$1" destination="$2" title="$3" detail="$4" mode="$5"
    local scale overlay
    case "$mode" in
        portrait)
            scale="scale=-2:920"
            overlay="overlay=x=1515:y=80"
            ;;
        landscape)
            scale="scale=1720:-2"
            overlay="overlay=x=(W-w)/2:y=355"
            ;;
        manager)
            scale="scale=-2:820"
            overlay="overlay=x=900:y=135"
            ;;
        *) echo "unknown card mode: $mode" >&2; exit 2 ;;
    esac
    ffmpeg -hide_banner -loglevel error -y \
        -f lavfi -i "color=c=0x070b14:s=1920x1080" -i "$source" \
        -filter_complex "[0]drawbox=x=0:y=0:w=1920:h=1080:color=0x07172d:t=fill,drawbox=x=0:y=0:w=620:h=1080:color=0x0b1324@0.94:t=fill,drawbox=x=70:y=110:w=8:h=120:color=0x58A6FF:t=fill,drawtext=fontfile='${font_bold}':text='${title}':fontcolor=white:fontsize=52:x=110:y=118,drawtext=fontfile='${font_regular}':text='${detail}':fontcolor=0xB8C5D8:fontsize=25:line_spacing=12:x=110:y=270[v];[1]${scale},format=rgba,drawbox=x=0:y=0:w=iw:h=ih:color=0x58A6FF@0.42:t=3[shot];[v][shot]${overlay}:format=auto,drawtext=fontfile='${font_regular}':text='EdgeHub v1.0.0-beta.1':fontcolor=0x7F93AF:fontsize=18:x=110:y=1015" \
        -frames:v 1 "$destination"
}

end_card() {
    local destination="$1"
    ffmpeg -hide_banner -loglevel error -y \
        -f lavfi -i "color=c=0x070b14:s=1920x1080" -i "$portrait" -i "$landscape" \
        -filter_complex "[0]drawbox=x=0:y=0:w=1920:h=1080:color=0x08172d:t=fill,drawbox=x=80:y=145:w=9:h=175:color=0xF47721:t=fill,drawtext=fontfile='${font_bold}':text='Build your Edge.':fontcolor=white:fontsize=72:x=125:y=150,drawtext=fontfile='${font_regular}':text='30 widgets. 19 preset screens. One live Manager.':fontcolor=0xC7D3E3:fontsize=30:x=125:y=270,drawtext=fontfile='${font_bold}':text='github.com/skyphoenix-it/skyphoenix-edgehub-linux':fontcolor=0x58A6FF:fontsize=28:x=125:y=865,drawtext=fontfile='${font_regular}':text='Independent project. Not affiliated with or endorsed by Corsair.':fontcolor=0x8798AF:fontsize=19:x=125:y=955[base];[1]scale=-2:690,format=rgba[p];[2]scale=1030:-2,format=rgba[l];[base][p]overlay=x=1540:y=80[tmp];[tmp][l]overlay=x=720:y=475" \
        -frames:v 1 "$destination"
}

clip() {
    local card_path="$1" duration="$2" destination="$3"
    ffmpeg -hide_banner -loglevel error -y -loop 1 -framerate 30 -i "$card_path" \
        -t "$duration" \
        -vf "zoompan=z='min(zoom+0.00018,1.025)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=30,fade=t=in:st=0:d=0.35,fade=t=out:st=$(awk -v d="$duration" 'BEGIN{printf "%.2f", d-0.35}'):d=0.35,format=yuv420p" \
        -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -an "$destination"
}

card "$portrait" "$work_dir/cards/01.png" \
    "Your Linux dashboard" "A native touch-first dashboard." portrait
card "$landscape" "$work_dir/cards/02.png" \
    "Live system widgets" "Live Linux metrics at a glance." landscape
card "$portrait" "$work_dir/cards/03.png" \
    "Portrait ready" "Widgets reflow for a tall canvas." portrait
card "$landscape" "$work_dir/cards/04.png" \
    "Turn the display" "KScreen turns. EdgeHub follows." landscape
card "$manager_base" "$work_dir/cards/05.png" \
    "Edit from your desktop" "A live desktop mirror over local IPC." manager
card "$manager_screens" "$work_dir/cards/06.png" \
    "Add screens live" "A new screen arrives instantly." manager
card "$manager_portrait" "$work_dir/cards/07.png" \
    "Preview portrait" "Arrange widgets from the desktop." manager
card "$manager_landscape" "$work_dir/cards/08.png" \
    "Preview landscape" "The preview reflows with the Hub." manager
card "$manager_light" "$work_dir/cards/09.png" \
    "Make it yours" "Themes, accents and backgrounds." manager
card "$manager_matrix" "$work_dir/cards/10.png" \
    "Changes arrive live" "Local sync. No cloud account." manager
end_card "$work_dir/cards/11.png"

durations=(5 6 4 4 6 6 4 4 3 3 7)
for index in $(seq -w 1 11); do
    array_index=$((10#$index - 1))
    clip "$work_dir/cards/${index}.png" "${durations[$array_index]}" \
         "$work_dir/clips/${index}.mp4"
done

concat_file="$work_dir/concat.txt"
for index in $(seq -w 1 11); do
    printf "file '%s'\n" "$work_dir/clips/${index}.mp4" >> "$concat_file"
done
ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$concat_file" \
    -c copy -movflags +faststart "$output_dir/edgehub-v1.0.0-beta.1-feature-tour.mp4"
ffmpeg -hide_banner -loglevel error -y -i "$work_dir/cards/06.png" \
    -vf "scale=1280:720" -frames:v 1 \
    "$output_dir/edgehub-v1.0.0-beta.1-video-thumbnail.png"
ffmpeg -hide_banner -loglevel error -y -i "$work_dir/cards/11.png" \
    -vf "scale=1600:900" -frames:v 1 \
    "$output_dir/edgehub-v1.0.0-beta.1-social-landscape.png"

# Copy-free website hero. Every visible product surface is a verified capture;
# the surrounding frame is only a deterministic presentation layout.
ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "color=c=0x071326:s=2400x1350" \
    -i "$manager_screens" -i "$landscape" -i "$portrait" \
    -filter_complex "[0]drawbox=x=0:y=0:w=2400:h=1350:color=0x08172d:t=fill,drawbox=x=0:y=980:w=2400:h=370:color=0x102749@0.7:t=fill[base];[1]scale=-2:760,format=rgba,drawbox=x=0:y=0:w=iw:h=ih:color=0xF47721@0.42:t=4[m];[2]scale=1880:-2,format=rgba,drawbox=x=0:y=0:w=iw:h=ih:color=0x58A6FF@0.45:t=4[l];[3]scale=-2:900,format=rgba,drawbox=x=0:y=0:w=iw:h=ih:color=0x9D68F5@0.45:t=4[p];[base][m]overlay=x=140:y=90[tmp1];[tmp1][l]overlay=x=130:y=790[tmp2];[tmp2][p]overlay=x=2100:y=120" \
    -frames:v 1 "$output_dir/edgehub-v1.0.0-beta.1-website-hero.png"

ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "color=c=0x071326:s=1200x1200" -i "$manager_screens" -i "$portrait" \
    -filter_complex "[0]drawbox=x=0:y=0:w=1200:h=1200:color=0x08172d:t=fill,drawbox=x=70:y=90:w=8:h=135:color=0xF47721:t=fill,drawtext=fontfile='${font_bold}':text='Build your Edge.':fontcolor=white:fontsize=58:x=110:y=105,drawtext=fontfile='${font_regular}':text='Widgets and screens. Live from Manager.':fontcolor=0xC7D3E3:fontsize=24:x=110:y=200[base];[1]scale=-2:720,format=rgba,drawbox=x=0:y=0:w=iw:h=ih:color=0x58A6FF@0.42:t=3[m];[2]scale=-2:790,format=rgba[p];[base][m]overlay=x=110:y=375[tmp];[tmp][p]overlay=x=940:y=300" \
    -frames:v 1 "$output_dir/edgehub-v1.0.0-beta.1-social-square.png"

ffprobe -v error -show_entries format=duration,size:stream=codec_name,width,height,r_frame_rate \
    -of json "$output_dir/edgehub-v1.0.0-beta.1-feature-tour.mp4"
