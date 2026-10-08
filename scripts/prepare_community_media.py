"""Prepare bundled content thumbnails and a traceable catalog; never modify source media."""
from pathlib import Path
import hashlib
import json
import subprocess
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'Koko/Resources/CommunityMedia'
NOTES = ROOT / 'ContentLibrary/collection-notes.json'


def prepare():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    notes = json.loads(NOTES.read_text())
    sources = sorted((ROOT / 'photos').glob('*.jpg')) + sorted((ROOT / 'photos').glob('*.webp')) + sorted((ROOT / 'videos').glob('*.mp4'))
    if set(notes) != {p.name for p in sources}:
        raise ValueError('Every source needs exactly one editorial entry in collection-notes.json')
    catalog = []
    for source in sources:
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        key = ('clip-' if source.suffix == '.mp4' else 'photo-') + hashlib.sha256(source.name.encode()).hexdigest()[:16]
        thumbnail = key + '-preview.jpg'
        entry = dict(notes[source.name], id=key, sourceFilename=source.name, sourceFolder=source.parent.name, sourceSHA256=digest, previewFilename=thumbnail)
        entry.setdefault('momentKey', key)
        if source.suffix == '.mp4':
            probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'quiet', '-show_format', '-show_streams', '-of', 'json', str(source)]))
            video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
            entry.update(mediaKind='video', pixelWidth=video['width'], pixelHeight=video['height'], durationSeconds=float(probe['format']['duration']))
            subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-ss', '0.5', '-i', str(source), '-frames:v', '1', '-vf', 'scale=640:640:force_original_aspect_ratio=decrease', '-q:v', '3', str(OUTPUT / thumbnail)], check=True)
        else:
            with Image.open(source) as raw:
                image = ImageOps.exif_transpose(raw).convert('RGB')
                entry.update(mediaKind='photo', pixelWidth=image.width, pixelHeight=image.height)
                if source.suffix == '.webp':
                    entry['displayFilename'] = key + '-display.jpg'
                    image.save(OUTPUT / entry['displayFilename'], quality=95)
                image.thumbnail((640, 640), Image.Resampling.LANCZOS)
                image.save(OUTPUT / thumbnail, quality=86)
        catalog.append(entry)
    # Interleave clips with photography so every format is visible in the opening feed.
    photos = [e for e in catalog if e['mediaKind'] == 'photo']
    videos = [e for e in catalog if e['mediaKind'] == 'video']
    ordered = []
    while photos or videos:
        if videos: ordered.append(videos.pop(0))
        for _ in range(4):
            if photos: ordered.append(photos.pop(0))
    (OUTPUT / 'community-media.json').write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + '\n')
    print(f'Prepared {sum(e["mediaKind"] == "photo" for e in ordered)} photos and {sum(e["mediaKind"] == "video" for e in ordered)} videos. Originals unchanged.')

if __name__ == '__main__':
    prepare()
