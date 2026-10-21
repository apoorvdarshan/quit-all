# Release notes

The iOS Release workflow publishes the GitHub Release for a `vX.Y.Z` tag with
the matching `## vX.Y.Z` section below. Without a matching section, GitHub
generates the notes from the merged pull requests. Add the section in the pull
request that bumps the version, before tagging. Keep one section per tag: an
empty or duplicated section fails the release before anything is built.

The App Store "What's New" text is separate: it lives in
`store/metadata/ios/<locale>/whats_new.txt` (see `store/README.md`).

## v1.2.3

Bug fixes and improvements. RevenueCat is updated to 5.96.0.

## v1.2.2

Quit All is now open source. About has new links to star the project on GitHub, report a bug or request a feature; the Instagram and Product Hunt links are updated; RevenueCat is updated to 5.95.0.

## v1.2.1

Maintenance update — cleaned up the About screen, plus performance and stability improvements.
