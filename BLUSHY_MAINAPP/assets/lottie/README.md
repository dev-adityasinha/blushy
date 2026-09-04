# Check-in card animations

Drop a Lottie file here named after the scene and the card uses it instead of
the drawn one. Nothing else has to change.

    water.json      a woman drinking
    sleep.json      a woman asleep
    movement.json   a woman running or walking
    stress.json     a woman breathing, sitting calmly
    energy.json     a woman stretching, arms up

The names come from `CheckinScene` in
`lib/features/home/widgets/checkin_scene.dart`. A file that is missing, or that
will not parse, falls back to the drawn scene — see `CheckinSceneView`.

## Before adding one

Check the licence. LottieFiles marks its free animations, and many are
CC0 or Lottie Simple Licence; some are not free to ship. Whoever adds a file
here is the person who has read its terms, which is why nothing is downloaded
automatically.

Keep them small. These sit on a card that is on the home page, so a
multi-megabyte animation is paid for on every open.
