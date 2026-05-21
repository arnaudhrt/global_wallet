import ProjectDescription

let project = Project(
    name: "Folio",
    organizationName: "Folio",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "MACOSX_DEPLOYMENT_TARGET": "14.0",
            "ENABLE_HARDENED_RUNTIME": "YES",
            "CODE_SIGN_STYLE": "Automatic",
            "CODE_SIGN_IDENTITY": "-",
            "DEVELOPMENT_TEAM": "",
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release"),
        ]
    ),
    targets: [
        .target(
            name: "Folio",
            destinations: .macOS,
            product: .app,
            bundleId: "co.bff.folio",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Folio",
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": "1",
                "LSApplicationCategoryType": "public.app-category.finance",
                "LSMinimumSystemVersion": "14.0",
                "NSHumanReadableCopyright": "© 2026 Folio",
            ]),
            sources: ["Folio/Sources/**"],
            dependencies: []
        ),
        .target(
            name: "FolioTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "co.bff.folio.tests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Folio/Tests/**"],
            dependencies: [.target(name: "Folio")]
        ),
    ]
)
