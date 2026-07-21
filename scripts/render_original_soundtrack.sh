#!/usr/bin/env bash
# Render an original ambient electronic soundtrack with no third-party samples.
set -euo pipefail

duration="${1:?usage: render_original_soundtrack.sh DURATION OUTPUT.wav}"
output="${2:?usage: render_original_soundtrack.sh DURATION OUTPUT.wav}"
work_dir="$(mktemp -d -p /tmp edgehub-soundtrack.XXXXXX)"
trap 'rm -rf -- "$work_dir"' EXIT INT TERM

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required" >&2; exit 2; }

roots=(220.00 174.61 261.63 196.00)
thirds=(261.63 220.00 329.63 246.94)
fifths=(329.63 261.63 392.00 293.66)
segments=$(( (${duration%.*} + 3) / 4 ))
concat_file="$work_dir/concat.txt"

for ((index=0; index<segments; index++)); do
    chord=$((index % 4))
    segment="$work_dir/segment-$(printf '%02d' "$index").wav"
    ffmpeg -hide_banner -loglevel error -y \
        -f lavfi -i "sine=frequency=${roots[$chord]}:sample_rate=48000:duration=4" \
        -f lavfi -i "sine=frequency=${thirds[$chord]}:sample_rate=48000:duration=4" \
        -f lavfi -i "sine=frequency=${fifths[$chord]}:sample_rate=48000:duration=4" \
        -f lavfi -i "sine=frequency=$(awk -v r="${roots[$chord]}" 'BEGIN { printf "%.3f", r/2 }'):sample_rate=48000:duration=4" \
        -f lavfi -i "aevalsrc=0.12*sin(2*PI*58*t)*exp(-32*mod(t\,0.5)):s=48000:d=4" \
        -filter_complex "[0]volume=0.050,tremolo=f=0.12:d=0.25[a0];[1]volume=0.038,tremolo=f=0.10:d=0.22[a1];[2]volume=0.032,tremolo=f=0.14:d=0.20[a2];[3]volume=0.055,lowpass=f=240[a3];[4]volume=0.24,lowpass=f=190[a4];[a0][a1][a2][a3][a4]amix=inputs=5:normalize=0,highpass=f=35,lowpass=f=4800,afade=t=in:st=0:d=0.08,afade=t=out:st=3.88:d=0.12" \
        -ar 48000 -ac 2 -c:a pcm_s16le "$segment"
    printf "file '%s'\n" "$segment" >> "$concat_file"
done

ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$concat_file" \
    -t "$duration" -af "afade=t=in:st=0:d=1.2,afade=t=out:st=$(awk -v d="$duration" 'BEGIN { printf "%.3f", d-2.0 }'):d=2,loudnorm=I=-19:TP=-2:LRA=7" \
    -ar 48000 -ac 2 -c:a pcm_s16le "$output"
