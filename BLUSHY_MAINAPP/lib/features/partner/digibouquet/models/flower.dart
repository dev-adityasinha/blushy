class Flower {
  final String id;
  final String name;
  final String image;
  final String monoImage;
  final String meaning;

  const Flower({
    required this.id,
    required this.name,
    required this.image,
    required this.monoImage,
    required this.meaning,
  });
}

class BushImage {
  final String base;
  final String top;

  const BushImage({required this.base, required this.top});
}

const List<Flower> flowers = [
  Flower(id: 'anemone', name: 'Anemone', image: 'assets/color/flowers/anemone.png', monoImage: 'assets/mono/flowers/anemone.png', meaning: 'Anticipation and excitement'),
  Flower(id: 'carnation', name: 'Carnation', image: 'assets/color/flowers/carnation.png', monoImage: 'assets/mono/flowers/carnation.png', meaning: 'Fascination and love'),
  Flower(id: 'dahlia', name: 'Dahlia', image: 'assets/color/flowers/dahlia.png', monoImage: 'assets/mono/flowers/dahlia.png', meaning: 'Elegance and inner strength'),
  Flower(id: 'daisy', name: 'Daisy', image: 'assets/color/flowers/daisy.png', monoImage: 'assets/mono/flowers/daisy.png', meaning: 'Innocence and purity'),
  Flower(id: 'lily', name: 'Lily', image: 'assets/color/flowers/lily.png', monoImage: 'assets/mono/flowers/lily.png', meaning: 'Pure love and devotion'),
  Flower(id: 'orchid', name: 'Orchid', image: 'assets/color/flowers/orchid.png', monoImage: 'assets/mono/flowers/orchid.png', meaning: 'Refinement and rare beauty'),
  Flower(id: 'peony', name: 'Peony', image: 'assets/color/flowers/peony.png', monoImage: 'assets/mono/flowers/peony.png', meaning: 'Romance and prosperity'),
  Flower(id: 'ranunculus', name: 'Ranunculus', image: 'assets/color/flowers/ranunculus.png', monoImage: 'assets/mono/flowers/ranunculus.png', meaning: 'Charm and attractiveness'),
  Flower(id: 'rose', name: 'Rose', image: 'assets/color/flowers/rose.png', monoImage: 'assets/mono/flowers/rose.png', meaning: 'Passion and true love'),
  Flower(id: 'sunflower', name: 'Sunflower', image: 'assets/color/flowers/sunflower.png', monoImage: 'assets/mono/flowers/sunflower.png', meaning: 'Adoration and loyalty'),
  Flower(id: 'tulip', name: 'Tulip', image: 'assets/color/flowers/tulip.png', monoImage: 'assets/mono/flowers/tulip.png', meaning: 'Perfect deep love'),
  Flower(id: 'zinnia', name: 'Zinnia', image: 'assets/color/flowers/zinnia.png', monoImage: 'assets/mono/flowers/zinnia.png', meaning: 'Endurance and lasting affection'),
];

const Map<String, List<BushImage>> bushImages = {
  'color': [
    BushImage(base: 'assets/color/bush/bush-1.png', top: 'assets/color/bush/bush-1-top.png'),
    BushImage(base: 'assets/color/bush/bush-2.png', top: 'assets/color/bush/bush-2-top.png'),
    BushImage(base: 'assets/color/bush/bush-3.png', top: 'assets/color/bush/bush-3-top.png'),
  ],
  'mono': [
    BushImage(base: 'assets/mono/bush/bush-2.png', top: 'assets/mono/bush/bush-2-top.png'),
  ],
};

Flower? getFlowerById(String id) {
  for (var f in flowers) {
    if (f.id == id) return f;
  }
  return null;
}
