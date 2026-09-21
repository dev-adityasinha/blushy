/// Web (and any target without dart:io) has no process environment to read.
/// Web widget tests are not used here, so warm-up never needs skipping.
bool get isUnderFlutterTest => false;
