# PolyglotRocks

<p align="left">
  <img alt="GitHub Workflow Status" src="https://img.shields.io/github/actions/workflow/status/clickcaramel/PolyglotRocks/test-branch.yml?label=tests">
  <img alt="GitHub" src="https://img.shields.io/github/license/clickcaramel/PolyglotRocks">
  <img alt="CocoaPods" src="https://img.shields.io/cocoapods/v/PolyglotRocks">
</p>

PolyglotRocks is a tool that simplifies the localization process for your iOS mobile app. By dropping in our SDK into your project and running the build, you can get AI translations instantly and manual ones a bit later.

## Usage

### CocoaPods

To install PolyglotRocks, add the following line to your Podfile:

```ruby
pod 'PolyglotRocks'
```

Then, run `pod install` to install the library.

To use PolyglotRocks in your Xcode project, add the following command to the build phase:

```plain
"${PODS_ROOT}/PolyglotRocks/bin/polyglot" <your token>
```

Replace `<your token>` with the API token provided by PolyglotRocks.

### Docker

PolyglotRocks can also be used with Docker. To get started, clone the repository and build the Docker image by running the following command:

```bash
docker build -t polyglot .
```

Once the image has been built, you can run a Docker container with the following command:

```bash
docker run --rm \
    --env "TOKEN=<your_token>" \
    --env "PRODUCT_BUNDLE_IDENTIFIER=<your_bundle_id>" \
    --volume "<path_to_project>:/home/polyglot/target" \
    polyglot
```

Replace `<your_token>`, `<your_bundle_id>`, and `<path_to_project>` with your API token, product bundle identifier, and the path to your Xcode project, respectively.

> Keep in mind that Docker uses absolute paths in volume mappings.

## License

**PolyglotRocks** is released under the Apache-2.0 license. See [LICENSE](./LICENSE) for details.
