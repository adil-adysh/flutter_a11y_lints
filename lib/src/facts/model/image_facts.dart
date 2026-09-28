import 'evidence.dart';

enum ImageContentState { unknown, present, absent }

enum ImageSourceKind { unknown, asset, network, file, memory }

class ImageFact {
  const ImageFact({
    required this.content,
    required this.sourceKind,
    required this.evidence,
    this.staticAssetPath,
    this.isKnownDecorativeAsset = false,
    this.isDefinitelyExcludedFromSemantics = false,
    this.isDefinitelyNotExcludedFromSemantics = false,
  });

  final ImageContentState content;
  final ImageSourceKind sourceKind;
  final String? staticAssetPath;
  final bool isKnownDecorativeAsset;
  final bool isDefinitelyExcludedFromSemantics;
  final bool isDefinitelyNotExcludedFromSemantics;
  final FactEvidence evidence;
}
