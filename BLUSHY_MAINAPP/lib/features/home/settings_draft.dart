import '../../core/state.dart';

/// A Settings draft, committed without undoing a stage change.
///
/// The Settings pages snapshot the profile when Edit is tapped and write the
/// snapshot back on Save. The life-stage selector on the same page saves
/// straight through to the server the moment a stage is tapped, so a Save
/// after that wrote the old stages over the new one -- and pushed them to
/// the account too, which is why the choice came back on the next start.
/// The draft carries every field she can edit on the page except the
/// stages, which are taken from the live profile.
PersonalContext keepCurrentStages(PersonalContext draft, PersonalContext current) {
  return draft.copyWith(
    lifeStage: current.lifeStage,
    activeLifeStages: Set<String>.from(current.activeLifeStages),
  );
}
