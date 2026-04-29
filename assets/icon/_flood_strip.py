"""Use flood-fill from corners to mark only OUTSIDE pixels as transparent,
keeping the inner white area of the pin intact."""
from collections import deque
from pathlib import Path
from PIL import Image

HERE = Path(__file__).parent
src = Image.open(HERE / "app_icon_transparent.png").convert("RGBA")
w, h = src.size
px = src.load()

def is_bg_like(r, g, b, a):
    """Light greyscale (the photo-editor checker)."""
    if a < 200:
        return True  # already transparent / soft
    sat = max(r, g, b) - min(r, g, b)
    if sat > 25:
        return False  # has color → icon
    return max(r, g, b) >= 170  # light grey or white

# BFS from corners — only flood through bg-like pixels
visited = set()
q = deque()
for x, y in [(0, 0), (w-1, 0), (0, h-1), (w-1, h-1)]:
    if is_bg_like(*px[x, y]):
        q.append((x, y))
        visited.add((x, y))

while q:
    x, y = q.popleft()
    for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]:
        nx, ny = x+dx, y+dy
        if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
            if is_bg_like(*px[nx, ny]):
                visited.add((nx, ny))
                q.append((nx, ny))

# Wipe the visited (= outside background) pixels
for x, y in visited:
    px[x, y] = (0, 0, 0, 0)

src.save(HERE / "app_icon_clean.png", "PNG")
print(f"Cleaned -> app_icon_clean.png ({len(visited)} px wiped)")
