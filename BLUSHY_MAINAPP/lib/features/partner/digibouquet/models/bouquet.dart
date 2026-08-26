class PlacedFlower {
  final String flowerId;
  double x;
  double y;
  double rotation;
  double scale;
  int zIndex;

  PlacedFlower({
    required this.flowerId,
    required this.x,
    required this.y,
    required this.rotation,
    required this.scale,
    required this.zIndex,
  });

  Map<String, dynamic> toJson() => {
        'flowerId': flowerId,
        'x': x,
        'y': y,
        'rotation': rotation,
        'scale': scale,
        'zIndex': zIndex,
      };

  factory PlacedFlower.fromJson(Map<String, dynamic> json) => PlacedFlower(
        flowerId: json['flowerId'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        rotation: (json['rotation'] as num).toDouble(),
        scale: (json['scale'] as num).toDouble(),
        zIndex: json['zIndex'] as int,
      );

  PlacedFlower clone() => PlacedFlower(
        flowerId: flowerId,
        x: x,
        y: y,
        rotation: rotation,
        scale: scale,
        zIndex: zIndex,
      );
}

class Bouquet {
  final String id;
  final List<String> flowers;
  final int greeneryIndex;
  final int seed;
  final String creator;
  final String mode; // 'color' or 'mono'
  final String message;
  final String wrappingPaper; // class name e.g., 'wrap-classic'
  final int ribbonColorIndex;
  final DateTime date;

  Bouquet({
    required this.id,
    required this.flowers,
    required this.greeneryIndex,
    required this.seed,
    required this.creator,
    required this.mode,
    required this.message,
    required this.wrappingPaper,
    required this.ribbonColorIndex,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'flowers': flowers,
        'greeneryIndex': greeneryIndex,
        'seed': seed,
        'creator': creator,
        'mode': mode,
        'message': message,
        'wrappingPaper': wrappingPaper,
        'ribbonColorIndex': ribbonColorIndex,
        'date': date.toIso8601String(),
      };

  factory Bouquet.fromJson(Map<String, dynamic> json) => Bouquet(
        id: json['id'].toString(),
        flowers: List<String>.from(json['flowers'] as List),
        greeneryIndex: json['greeneryIndex'] as int,
        seed: json['seed'] as int,
        creator: json['creator'] as String? ?? '',
        mode: json['mode'] as String? ?? 'color',
        message: json['message'] as String? ?? '',
        wrappingPaper: json['wrappingPaper'] as String? ?? 'wrap-classic',
        ribbonColorIndex: json['ribbonColorIndex'] as int? ?? 0,
        date: DateTime.parse(json['date'] as String),
      );
}
