/**
 * Guided recovery sessions.
 *
 * The Recovery tab advertised named sessions with durations -- "Period Pain
 * Relief Meditation • 12 min", "Luteal Phase Anxiety Breathing • 8 min" -- and
 * both cards were `onTap: () {}`. There was no player and no content.
 *
 * Two rules shaped what is seeded here.
 *
 * A session is a sequence of timed steps, not an audio file. That makes it
 * something the app can actually deliver today, and something a reviewer can
 * read line by line rather than having to listen to a recording.
 *
 * And nothing here claims a therapeutic effect. The old titles asserted that a
 * meditation relieves period pain and that a breathing exercise treats luteal
 * phase anxiety; those are clinical claims, and this file is not the place to
 * make them. What is seeded are plainly named relaxation techniques described
 * by what you do. If Blushy wants to offer the clinically framed sessions, a
 * named reviewer has to write and sign them off -- which is exactly what the
 * `clinical_review` status below is for: these do not serve until approved.
 */

function session({
  contentId,
  title,
  summary,
  steps,
  lifeStages = [],
  topics = ['recovery'],
}) {
  const totalSeconds = steps.reduce((sum, step) => sum + step.seconds, 0);

  return {
    contentId,
    title,
    summary,
    // The steps are the session. Stored as JSON so a reviewer edits the same
    // text the app reads out.
    body: JSON.stringify({ steps }),
    contentType: 'recovery_session',
    readingTimeMinutes: Math.max(1, Math.round(totalSeconds / 60)),
    lifeStages,
    topics,
    audience: 'female_user',
    source: 'Blushy guided relaxation, technique only',
  };
}

export const RECOVERY_SESSION_SEED = [
  session({
    contentId: 'rs_box_breathing',
    title: 'Box breathing',
    summary: 'Four seconds in, hold, four out, hold. A steady rhythm to settle into.',
    steps: [
      { instruction: 'Sit comfortably and let your shoulders drop.', seconds: 15 },
      { instruction: 'Breathe in slowly.', seconds: 4 },
      { instruction: 'Hold.', seconds: 4 },
      { instruction: 'Breathe out slowly.', seconds: 4 },
      { instruction: 'Hold.', seconds: 4 },
      { instruction: 'Breathe in slowly.', seconds: 4 },
      { instruction: 'Hold.', seconds: 4 },
      { instruction: 'Breathe out slowly.', seconds: 4 },
      { instruction: 'Hold.', seconds: 4 },
      { instruction: 'Let your breathing return to its own pace.', seconds: 20 },
    ],
  }),

  session({
    contentId: 'rs_long_exhale',
    title: 'Longer exhale',
    summary: 'Breathe out for longer than you breathe in, and let the pace slow.',
    steps: [
      { instruction: 'Settle somewhere you can stay still for a few minutes.', seconds: 15 },
      { instruction: 'Breathe in gently.', seconds: 4 },
      { instruction: 'Breathe out slowly, longer than you breathed in.', seconds: 6 },
      { instruction: 'Breathe in gently.', seconds: 4 },
      { instruction: 'Breathe out slowly.', seconds: 6 },
      { instruction: 'Breathe in gently.', seconds: 4 },
      { instruction: 'Breathe out slowly.', seconds: 6 },
      { instruction: 'Rest, and let your breathing find its own rhythm.', seconds: 25 },
    ],
  }),

  session({
    contentId: 'rs_body_scan',
    title: 'Body scan',
    summary: 'Move your attention slowly through the body, without trying to change anything.',
    steps: [
      { instruction: 'Lie down or sit back, and close your eyes if that is comfortable.', seconds: 20 },
      { instruction: 'Notice your feet. Nothing to change, just notice.', seconds: 30 },
      { instruction: 'Move your attention to your legs.', seconds: 30 },
      { instruction: 'Notice your hips and lower back.', seconds: 30 },
      { instruction: 'Notice your stomach, and how it moves as you breathe.', seconds: 30 },
      { instruction: 'Move up to your chest and shoulders.', seconds: 30 },
      { instruction: 'Notice your arms, down to your hands.', seconds: 30 },
      { instruction: 'Notice your jaw, and let it be loose.', seconds: 30 },
      { instruction: 'Take in the whole body for a moment.', seconds: 30 },
      { instruction: 'When you are ready, open your eyes.', seconds: 20 },
    ],
  }),

  session({
    contentId: 'rs_progressive_release',
    title: 'Tense and release',
    summary: 'Tighten one area at a time, then let it go, and notice the difference.',
    steps: [
      { instruction: 'Sit or lie somewhere you can stay for a few minutes.', seconds: 15 },
      { instruction: 'Curl your toes and hold.', seconds: 8 },
      { instruction: 'Let go, and notice how that feels.', seconds: 15 },
      { instruction: 'Tighten your legs and hold.', seconds: 8 },
      { instruction: 'Let go.', seconds: 15 },
      { instruction: 'Make fists and hold.', seconds: 8 },
      { instruction: 'Let go.', seconds: 15 },
      { instruction: 'Lift your shoulders towards your ears and hold.', seconds: 8 },
      { instruction: 'Let them drop.', seconds: 20 },
      { instruction: 'Rest here for a moment before you get up.', seconds: 20 },
    ],
  }),

  session({
    contentId: 'rs_settling_before_sleep',
    title: 'Settling before sleep',
    summary: 'A slow wind-down for when you are lying down and ready to stop.',
    steps: [
      { instruction: 'Get comfortable, and let the day be over.', seconds: 25 },
      { instruction: 'Breathe out slowly and let your body sink into the bed.', seconds: 20 },
      { instruction: 'Unclench your jaw.', seconds: 20 },
      { instruction: 'Let your shoulders drop away from your ears.', seconds: 20 },
      { instruction: 'Let your hands rest open.', seconds: 20 },
      { instruction: 'Follow your breathing without changing it.', seconds: 45 },
      { instruction: 'If your mind wanders, come back to the breath. That is the exercise.', seconds: 45 },
      { instruction: 'Stay here as long as you like.', seconds: 30 },
    ],
  }),
];

export const RECOVERY_SESSION_COUNT = RECOVERY_SESSION_SEED.length;
