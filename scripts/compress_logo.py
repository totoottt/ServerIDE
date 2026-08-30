from PIL import Image
from pathlib import Path

root = Path('/home/ubuntu/server-ide-mobile/assets/images')
source = Image.open(root / 'icon.png').convert('RGBA')
source.thumbnail((512, 512), Image.Resampling.LANCZOS)
for name in ['icon.png', 'splash-icon.png', 'favicon.png', 'android-icon-foreground.png']:
    source.save(root / name, format='PNG', optimize=True, compress_level=9)
