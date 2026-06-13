fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Upload App Store metadata (no binary, no screenshots) via App Store Connect API key.

Reads ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_FILEPATH from fastlane/.env.

### ios inspect_app

```sh
[bundle exec] fastlane ios inspect_app
```

Diagnostic: print the app's reserved name, primary locale, and existing localizations.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
