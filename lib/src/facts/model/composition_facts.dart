import 'evidence.dart';

enum NodeCreationState { unknown, noNewNode, createsNode }

enum ChildContributionState { unknown, mayContribute, mustRemainExplicit }

enum DescendantDisposition { unknown, preserved, replaced, excluded }

enum MergeState { unknown, notMerged, merged }

class CompositionFact {
  const CompositionFact({
    required this.nodeCreation,
    required this.descendantDisposition,
    required this.evidence,
    this.childContribution = ChildContributionState.unknown,
    this.merge = MergeState.unknown,
    this.blocksUserActions = false,
  });

  final NodeCreationState nodeCreation;
  final ChildContributionState childContribution;
  final DescendantDisposition descendantDisposition;
  final MergeState merge;
  final bool blocksUserActions;
  final FactEvidence evidence;
}
