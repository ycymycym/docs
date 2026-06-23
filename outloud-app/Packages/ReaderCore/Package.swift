// swift-tools-version: 5.10
import PackageDescription

// ReaderCore — the shared engine used by both the Outloud host app and the
// Share Extension. Everything that is platform-logic (text extraction,
// chunking, synthesis, playback, paywall, library) lives here so the two app
// targets stay thin.
//
// NOTE on the Kokoro dependency: the brief calls for `mlalma/kokoro-ios`
// (product `KokoroSwift`, MLX-backed). Its API was confirmed against the repo
// README (KokoroTTS(modelPath:g2p:) / generateAudio(voice:language:text:)) but
// the README warns signatures can drift, so the dependency is *pinned* and the
// integration is isolated in KokoroEngine/KokoroSpeechEngine.swift. If you bump
// the version, re-verify that one file only.
let package = Package(
    name: "ReaderCore",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "ReaderCore", targets: ["ReaderCore"])
    ],
    dependencies: [
        // Pinned. Re-verify the adapter in KokoroSpeechEngine.swift on any bump.
        .package(url: "https://github.com/mlalma/kokoro-ios.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "ReaderCore",
            dependencies: [
                .product(name: "KokoroSwift", package: "kokoro-ios")
            ],
            resources: [
                // Mozilla Readability, injected into an offscreen WKWebView.
                .copy("TextExtraction/Readability.js")
            ]
        ),
        .testTarget(
            name: "ReaderCoreTests",
            dependencies: ["ReaderCore"]
        )
    ]
)
