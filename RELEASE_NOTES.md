# Release notes

The iOS Release workflow publishes the GitHub Release for a `vX.Y.Z` tag with
the matching `## vX.Y.Z` section below. Without a matching section, GitHub
generates the notes from the merged pull requests. Add the section in the pull
request that bumps the version, before tagging.

The App Store "What's New" text is separate: it lives in
`store/metadata/ios/<locale>/whats_new.txt` (see `store/README.md`).

## v1.2.1

Maintenance update — cleaned up the About screen, plus performance and stability improvements.
