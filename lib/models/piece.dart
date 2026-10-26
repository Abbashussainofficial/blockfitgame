import 'piece_shape.dart';

/// A concrete piece dealt to the tray. [id] is unique per deal so the UI can
/// tell two pieces with the same shape apart (for keys and animations).
class Piece {
  const Piece({required this.id, required this.shape});

  final int id;
  final PieceShape shape;

  Map<String, Object> toJson() => {'id': id, 'shape': shape.id};

  @override
  bool operator ==(Object other) =>
      other is Piece && other.id == id && other.shape.id == shape.id;

  @override
  int get hashCode => Object.hash(id, shape.id);

  @override
  String toString() => 'Piece#$id(${shape.id})';
}
