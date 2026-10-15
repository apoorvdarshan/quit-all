# Contributing to Quit All

Thanks for your interest in contributing! Quit All is an iOS app for quitting habits, plus its website. The repository is a monorepo:

- `ios/` — SwiftUI iOS app, Home and Lock Screen widget, unit and UI tests
- `web/` — static marketing site and API Worker at [quit-all.com](https://quit-all.com), deployed to Cloudflare Workers
- `store/` and `scripts/` — App Store listing and the release automation

Bug reports, feature ideas and pull requests are welcome.

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## Getting Started (iOS)

1. Fork the repository and clone your fork
2. Open `ios/Quit All.xcodeproj` in Xcode 27
3. Build and run on a simulator or device running iOS 17.6 or later

Debug simulator builds have a test mode that never contacts RevenueCat, the App Store or KLIPY; see [iOS testing](docs/ios-testing.md).

## Getting Started (Web)

```bash
cd web
npm ci
npm run dev    # http://localhost:8787
```

Pages are TypeScript templates in `web/src/site/` (content in `web/src/site/content/`), rendered to plain HTML in `web/dist/` by `npm run build`; styles and the one page script live in `web/public/assets/`. `npm run dev` serves the built site and the API Worker in the Cloudflare Workers runtime. The KLIPY proxy needs a `KLIPY_API_KEY` secret; without one it answers with an error, which is fine for most site work.

## Code Style

- Follow the patterns already used next to the code you change.
- **iOS:** SwiftUI with `@Observable` models and Core Data for local storage. Xcode discovers files through synchronized folders, so don't edit `project.pbxproj` just to add a source file. User-facing text lives in the `*.lproj/Localizable.strings` files; add new English strings and update the other languages where practical.
- **Web:** no framework. TypeScript with `strict` mode for the templates, build and Worker; plain CSS and JavaScript in `public/`. Keep `npm run lint` free of errors and warnings.
- Never commit API keys, signing material or other credentials. Secrets live in GitHub Actions secrets and Cloudflare Worker secrets.

## Automated tests and checks

Major new functionality must include automated tests for its behavior, and bug fixes should include a regression test when practical. Cover valid input, invalid input and failure paths. Explain any testing limitation in the pull request.

Run the checks relevant to your change before opening a pull request:

```bash
# iOS unit and UI tests on a temporary simulator (Mac with Xcode 27)
bash scripts/test-ios.sh

# Website: lint, type check, tests (including generated-input fuzz tests) and build
cd web
npm ci
npm run check

# Release tooling (offline; never contacts App Store Connect)
python3 -m unittest -v scripts/store/test_ios_release.py
```

The website tests include fast-check property tests for the KLIPY proxy that run 1,000 generated cases per property. A failure prints a seed and a shrunk counterexample; rerun it with `FUZZ_SEED=<seed> npm test`, or raise `FUZZ_RUNS` for a longer run.

GitHub Actions runs these checks automatically:

- **iOS tests** — unit and UI tests for pull requests and pushes that change the app
- **Web** — lint, type check, tests, build and a smoke test for changes under `web/`, plus a weekly longer fuzzing run
- **Store automation (offline)** — release-tooling tests for changes to the store tooling or listing
- **CodeQL** and **Dependency review** — static analysis and vulnerable-dependency checks on every pull request
- **OpenSSF Scorecard** — weekly supply-chain security review

## Pull Requests

1. Create a branch from `main`; `main` only accepts changes through pull requests
2. Keep changes focused — one feature or fix per pull request
3. Make sure the required checks pass and resolve review conversations
4. Explain **why** the change is needed, not just what it does

## Release notes

iOS release tags are `vX.Y.Z` and must match `MARKETING_VERSION`. Before tagging, add a matching `## vX.Y.Z` section to [`RELEASE_NOTES.md`](RELEASE_NOTES.md) that summarizes user-visible changes and any publicly known security fixes, including identifiers such as CVEs when available. See [store/README.md](store/README.md) for the release pipeline.

## Reporting Issues

- **Bug:** [open a bug report](https://github.com/apoorvdarshan/quit-all/issues/new?template=bug_report.yml) with steps to reproduce, expected and actual behavior, device, iOS version and app version
- **Feature:** [open a feature request](https://github.com/apoorvdarshan/quit-all/issues/new?template=feature_request.yml) describing the problem and the proposed solution

Security issues: use [private vulnerability reporting](https://github.com/apoorvdarshan/quit-all/security/advisories/new), not a public issue. See [SECURITY.md](SECURITY.md).

## Contact

- **Email:** ad13dtu@gmail.com
- **X:** [@apoorvdarshan](https://x.com/apoorvdarshan)
- **GitHub Issues:** [github.com/apoorvdarshan/quit-all/issues](https://github.com/apoorvdarshan/quit-all/issues)

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
