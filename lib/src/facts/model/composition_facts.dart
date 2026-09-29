import 'evidence.dart';

/// A source boolean that is either statically known, dynamic, or unresolved.
enum KnownBooleanState { unknown, trueValue, falseValue, dynamic }

/// How a recognized Flutter semantic-constructor argument was established.
enum ArgumentEvidenceOrigin { defaultValue, literal, resolved, dynamic }

class KnownBooleanFact {
  const KnownBooleanFact({required this.state, required this.origin});

  const KnownBooleanFact.unknown()
      : state = KnownBooleanState.unknown,
        origin = ArgumentEvidenceOrigin.dynamic;

  final KnownBooleanState state;
  final ArgumentEvidenceOrigin origin;
}

/// Raw configuration for a recognized `Semantics` constructor.
///
/// Defaults are facts only when supplied by the documented constructor
/// contract; unresolved expressions remain dynamic or unknown.
class RawSemanticsConfigurationFact {
  const RawSemanticsConfigurationFact({
    required this.container,
    required this.explicitChildNodes,
    required this.excludeSemantics,
    required this.blockUserActions,
  });

  final KnownBooleanFact container;
  final KnownBooleanFact explicitChildNodes;
  final KnownBooleanFact excludeSemantics;
  final KnownBooleanFact blockUserActions;
}

enum NodeCreationState { unknown, noNewNode, createsNode }

enum ChildContributionState { unknown, mayContribute, mustRemainExplicit }

enum DescendantDisposition { unknown, preserved, replaced, excluded }

enum MergeState { unknown, notMerged, merged }

/// Whether a recognized `Semantics` wrapper contributes configuration beyond
/// a role-only annotation. This is intentionally independent of the wrapper's
/// resulting role and child composition.
enum SemanticsConfigurationState {
  unknown,
  noMeaningfulArguments,
  meaningful,
}

class CompositionFact {
  const CompositionFact({
    required this.nodeCreation,
    required this.descendantDisposition,
    required this.evidence,
    this.childContribution = ChildContributionState.unknown,
    this.merge = MergeState.unknown,
    this.configuration = SemanticsConfigurationState.unknown,
    this.blocksUserActions = const KnownBooleanFact.unknown(),
    this.explicitButtonRole = const KnownBooleanFact.unknown(),
    this.rawSemanticsConfiguration,
  });

  final NodeCreationState nodeCreation;
  final ChildContributionState childContribution;
  final DescendantDisposition descendantDisposition;
  final MergeState merge;
  final SemanticsConfigurationState configuration;
  final KnownBooleanFact blocksUserActions;
  final KnownBooleanFact explicitButtonRole;
  final RawSemanticsConfigurationFact? rawSemanticsConfiguration;
  final FactEvidence evidence;
}
