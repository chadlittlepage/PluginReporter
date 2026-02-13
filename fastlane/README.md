fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### build_all

```sh
[bundle exec] fastlane build_all
```

Build all platforms

### test_all

```sh
[bundle exec] fastlane test_all
```

Test all platforms

### quick_build

```sh
[bundle exec] fastlane quick_build
```

Quick build check (no tests)

----


## Mac

### mac test

```sh
[bundle exec] fastlane mac test
```

Run tests for macOS

### mac build

```sh
[bundle exec] fastlane mac build
```

Build macOS app (Release)

### mac release

```sh
[bundle exec] fastlane mac release
```

Full release: test + build

----


## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests for iOS

### ios build

```sh
[bundle exec] fastlane ios build
```

Build iOS app (Debug for Simulator)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight (requires Apple Developer Account)

### ios release

```sh
[bundle exec] fastlane ios release
```

Submit to App Store (requires Apple Developer Account)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
