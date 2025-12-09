from PIL import Image, ImageDraw

def crop_to_circle(image_path, output_path):
    img = Image.open(image_path).convert("RGBA")
    size = min(img.size)
    
    # Create a square canvas
    img = img.crop(((img.width - size) // 2,
                    (img.height - size) // 2,
                    (img.width + size) // 2,
                    (img.height + size) // 2))
    
    # Create circle mask
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask) 
    draw.ellipse((0, 0, size, size), fill=255)
    
    # Apply mask
    result = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    result.paste(img, (0, 0), mask=mask)
    
    result.save(output_path)
    print(f"Created circular icon at {output_path}")

try:
    crop_to_circle('assets/icon.png', 'assets/icon.png')
except Exception as e:
    print(f"Error: {e}")
