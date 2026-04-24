const Map<int, String> categoryDefaultImages = {
  1: 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=600&h=400&fit=crop',
  2: 'https://images.unsplash.com/photo-1571008887538-b36bb32f4571?w=600&h=400&fit=crop',
  3: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=600&h=400&fit=crop',
  4: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&h=400&fit=crop',
  5: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=600&h=400&fit=crop',
  6: 'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=600&h=400&fit=crop',
  7: 'https://images.unsplash.com/photo-1503095396549-807759245b35?w=600&h=400&fit=crop',
  8: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&h=400&fit=crop',
  9: 'https://images.unsplash.com/photo-1565791380709-49e529c8b073?w=600&h=400&fit=crop',
  10: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=600&h=400&fit=crop',
};

const Map<String, int> categoryNameToId = {
  'Yürüyüş': 1,
  'Koşu': 2,
  'Halı Saha': 3,
  'Basketbol': 4,
  'Bisiklet': 5,
  'Konser': 6,
  'Tiyatro': 7,
  'Yemek': 8,
  'Müze': 9,
  'Sinema': 10,
};

String activityImageUrl({String? imageUrl, int? categoryId, String? categoryName}) {
  if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
  final id = categoryId ?? (categoryName != null ? categoryNameToId[categoryName] : null);
  return categoryDefaultImages[id] ?? categoryDefaultImages[1]!;
}
