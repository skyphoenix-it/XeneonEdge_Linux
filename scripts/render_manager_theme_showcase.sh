#!/usr/bin/env bash
# Render the 20 Free themes from exact-candidate Manager captures.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input_dir="${1:-${repo_dir}/captures/v1.0.0-beta.1/raw/themes}"
output_dir="${2:-${repo_dir}/captures/v1.0.0-beta.1/final}"
font_regular="${repo_dir}/assets/fonts/Lexend-Regular.ttf"
font_bold="${repo_dir}/assets/fonts/Lexend-Bold.ttf"
work_dir="$(mktemp -d -p /tmp edgehub-themes.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT INT TERM

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required" >&2; exit 2; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe is required" >&2; exit 2; }
install -d "$output_dir" "$work_dir/cards" "$work_dir/clips"

theme_names=("Dark" "Midnight" "Aurora" "Sunset" "Nebula" "Forest" "Ocean" "Ember" "Rose Gold" "Nord" "Dracula" "Solarized" "Gruvbox" "Catppuccin" "Tokyo Night" "Aubergine" "Crimson" "OLED" "Light" "Contrast")
accent_names=("Blue" "Purple" "Green" "Orange" "Pink" "Teal" "Red" "Gold" "Cyan" "Magenta")
mapfile -t theme_frames < <(find "$input_dir" -maxdepth 1 -type f -name 'edgehub-v1.0.0-beta.1-manager-theme-*.png' | sort)
mapfile -t accent_frames < <(find "$input_dir" -maxdepth 1 -type f -name 'edgehub-v1.0.0-beta.1-manager-accent-*.png' | sort)
[ "${#theme_frames[@]}" -eq 20 ] || { echo "expected 20 theme frames, found ${#theme_frames[@]}" >&2; exit 2; }
[ "${#accent_frames[@]}" -eq 10 ] || { echo "expected 10 accent frames, found ${#accent_frames[@]}" >&2; exit 2; }

for index in "${!theme_frames[@]}"; do
    number=$((index + 1))
    card="$work_dir/cards/$(printf '%02d' "$number").png"
    ffmpeg -hide_banner -loglevel error -y \
        -f lavfi -i "color=c=0x070b14:s=1920x1080" -i "${theme_frames[$index]}" \
        -filter_complex "[0]drawbox=x=0:y=0:w=1920:h=1080:color=0x07172d:t=fill,drawbox=x=0:y=0:w=590:h=1080:color=0x0b1324@0.96:t=fill,drawbox=x=74:y=115:w=8:h=126:color=0x58A6FF:t=fill,drawtext=fontfile='${font_bold}':text='${theme_names[$index]}':fontcolor=white:fontsize=58:x=112:y=122,drawtext=fontfile='${font_regular}':text='Theme ${number} of 20 included in Free':fontcolor=0xB8C5D8:fontsize=25:x=112:y=275,drawtext=fontfile='${font_regular}':text='Exact beta.1 Manager preview':fontcolor=0x7F93AF:fontsize=19:x=112:y=1012[base];[1]scale=-2:1000,format=rgba,drawbox=x=0:y=0:w=iw:h=ih:color=0x58A6FF@0.36:t=3[shot];[base][shot]overlay=x=760:y=40" \
        -frames:v 1 "$card"
done

for index in "${!accent_frames[@]}"; do
    number=$((index + 21))
    accent_number=$((index + 1))
    card="$work_dir/cards/$(printf '%02d' "$number").png"
    ffmpeg -hide_banner -loglevel error -y \
        -f lavfi -i "color=c=0x070b14:s=1920x1080" -i "${accent_frames[$index]}" \
        -filter_complex "[0]drawbox=x=0:y=0:w=1920:h=1080:color=0x07172d:t=fill,drawbox=x=0:y=0:w=590:h=1080:color=0x0b1324@0.96:t=fill,drawbox=x=74:y=115:w=8:h=126:color=0xF47721:t=fill,drawtext=fontfile='${font_bold}':text='${accent_names[$index]} accent':fontcolor=white:fontsize=52:x=112:y=122,drawtext=fontfile='${font_regular}':text='Accent ${accent_number} of 10 on Nord':fontcolor=0xB8C5D8:fontsize=25:x=112:y=275,drawtext=fontfile='${font_regular}':text='Exact beta.1 Manager preview':fontcolor=0x7F93AF:fontsize=19:x=112:y=1012[base];[1]scale=-2:1000,format=rgba,drawbox=x=0:y=0:w=iw:h=ih:color=0xF47721@0.36:t=3[shot];[base][shot]overlay=x=760:y=40" \
        -frames:v 1 "$card"
done

for index in $(seq -w 1 30); do
    clip="$work_dir/clips/${index}.mp4"
    ffmpeg -hide_banner -loglevel error -y -loop 1 -framerate 30 -i "$work_dir/cards/${index}.png" \
        -t 1.5 -vf "zoompan=z='min(zoom+0.00012,1.012)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=30,fade=t=in:st=0:d=0.15,fade=t=out:st=1.35:d=0.15,format=yuv420p" \
        -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -an "$clip"
done

concat_file="$work_dir/concat.txt"
for index in $(seq -w 1 30); do
    printf "file '%s'\n" "$work_dir/clips/${index}.mp4" >> "$concat_file"
done
ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$concat_file" \
    -c copy "$work_dir/theme-showcase-silent.mp4"
"${repo_dir}/scripts/render_original_soundtrack.sh" 45 "$work_dir/theme-showcase.wav"
ffmpeg -hide_banner -loglevel error -y -i "$work_dir/theme-showcase-silent.mp4" \
    -i "$work_dir/theme-showcase.wav" -c:v copy -c:a aac -b:a 192k -shortest \
    -movflags +faststart "$output_dir/edgehub-v1.0.0-beta.1-manager-theme-showcase.mp4"

# A large 5x4 proof sheet. It keeps the complete Manager window in every tile.
tile_inputs=()
for index in $(seq -w 1 20); do tile_inputs+=( -i "$work_dir/cards/${index}.png" ); done
filter=""
for index in $(seq 0 19); do filter+="[${index}:v]scale=480:270[t${index}];"; done
filter+="[t0][t1][t2][t3][t4][t5][t6][t7][t8][t9][t10][t11][t12][t13][t14][t15][t16][t17][t18][t19]xstack=inputs=20:layout=0_0|480_0|960_0|1440_0|1920_0|0_270|480_270|960_270|1440_270|1920_270|0_540|480_540|960_540|1440_540|1920_540|0_810|480_810|960_810|1440_810|1920_810[out]"
ffmpeg -hide_banner -loglevel error -y "${tile_inputs[@]}" \
    -filter_complex "$filter" -map '[out]' -frames:v 1 \
    "$output_dir/edgehub-v1.0.0-beta.1-manager-theme-sheet.png"

accent_inputs=()
for index in $(seq 21 30); do accent_inputs+=( -i "$work_dir/cards/${index}.png" ); done
accent_filter=""
for index in $(seq 0 9); do accent_filter+="[${index}:v]scale=480:270[a${index}];"; done
accent_filter+="[a0][a1][a2][a3][a4][a5][a6][a7][a8][a9]xstack=inputs=10:layout=0_0|480_0|960_0|1440_0|1920_0|0_270|480_270|960_270|1440_270|1920_270[out]"
ffmpeg -hide_banner -loglevel error -y "${accent_inputs[@]}" \
    -filter_complex "$accent_filter" -map '[out]' -frames:v 1 \
    "$output_dir/edgehub-v1.0.0-beta.1-manager-accent-sheet.png"

cp "$work_dir/cards/03.png" "$output_dir/edgehub-v1.0.0-beta.1-manager-theme-showcase-thumbnail.png"
ffprobe -v error -show_entries format=duration,size:stream=codec_name,width,height,r_frame_rate \
    -of json "$output_dir/edgehub-v1.0.0-beta.1-manager-theme-showcase.mp4"
