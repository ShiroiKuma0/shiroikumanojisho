# Changelog

## 2.0.6

- Fix typo in README again (every bloody time!)

## 2.0.5

- Incorporate Provider v6.0.0
  - (From a PR by https://github.com/T1G3R192 which couldn't be merged directly. Thanks, Jahn E.)

## 2.0.4

- Fix typo in README again

## 2.0.3

- Integrate fixes for poor null-safety conversion (thanks @jja08111)

## 2.0.2

- Updated typo in README

## 2.0.1

- 2.0.0-nullsafety.0 pushed from prerelease to full release

## 2.0.0-nullsafety.0

- Updated dependencies
- Used the dart migrate tool to migrate to nullsafety
- Removed 2 now-useless null checks

## 1.0.3

- Compiles for the Web platform

## 1.0.2

- Add parent bundle id/package name to MusizBrainz UA for recognition of possible commercial app usage
- Expose `DefaultNowPlayingImageResolver` so that it can be extended
- Make track info refresh when app foregrounded
- Change logic re: updating caller when track finshes playing

## 1.0.1

- Meet need to know status of permissions on Android at start up, with breaking change: change `start` method return type from `void` to `Future<void>`

## 0.1.4

- fix bug with image resolution, whereby existing image was discarded

## 0.1.3

- improved image resolution algorithm

## 0.1.2

- deal with shonky iOS now playing information, which variously returns
  images and persistent IDs as empty or zero
- improve in-code documentation

## 0.1.1

- remove unnecessary imports and ChangeNotifier

## 0.1.0

- initial release
- stream of now playing tracks
- optional resolution of missing album art
