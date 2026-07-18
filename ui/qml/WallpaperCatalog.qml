import QtQuick

// WallpaperCatalog — the set of bundled "standard" page backgrounds that ship
// with the app (720×2560, tuned to the built-in themes). Shared by the hub's
// SettingsPanel and the Manager so both offer the same list. User-uploaded
// images (via the Manager) are listed separately by the Manager itself.
QtObject {
    readonly property var items: [
        { name: "midnight", label: "Midnight", source: "qrc:/wallpapers/midnight.png" },
        { name: "nebula",   label: "Nebula",   source: "qrc:/wallpapers/nebula.png" },
        { name: "aurora",   label: "Aurora",   source: "qrc:/wallpapers/aurora.png" },
        { name: "ocean",    label: "Ocean",    source: "qrc:/wallpapers/ocean.png" },
        { name: "teal",     label: "Teal",     source: "qrc:/wallpapers/teal.png" },
        { name: "sunset",   label: "Sunset",   source: "qrc:/wallpapers/sunset.png" },
        { name: "ember",    label: "Ember",    source: "qrc:/wallpapers/ember.png" },
        { name: "grape",    label: "Grape",    source: "qrc:/wallpapers/grape.png" },
        { name: "blossom",  label: "Blossom",  source: "qrc:/wallpapers/blossom.png" },
        { name: "graphite", label: "Graphite", source: "qrc:/wallpapers/graphite.png" },
        { name: "slate",    label: "Slate",    source: "qrc:/wallpapers/slate.png" },
        { name: "daylight", label: "Daylight", source: "qrc:/wallpapers/daylight.png" },
        // Extra candidates (added for review) — richer generated backgrounds and a
        // few NASA public-domain photos. All center-composed so they read well in
        // both 720x2560 and 2560x720. Trim this list to taste.
        { name: "mesh-aurora", label: "Aurora Mesh", source: "qrc:/wallpapers/mesh-aurora.png" },
        { name: "mesh-ocean",  label: "Ocean Mesh",  source: "qrc:/wallpapers/mesh-ocean.png" },
        { name: "mesh-violet", label: "Violet Mesh", source: "qrc:/wallpapers/mesh-violet.png" },
        { name: "mesh-sunset", label: "Sunset Mesh", source: "qrc:/wallpapers/mesh-sunset.png" },
        { name: "starfield",   label: "Starfield",   source: "qrc:/wallpapers/starfield.png" },
        { name: "dawn",        label: "Dawn",        source: "qrc:/wallpapers/dawn.png" },
        { name: "photo-nebula",    label: "Nebula (NASA)",   source: "qrc:/wallpapers/photo-nebula.jpg" },
        { name: "photo-galaxy",    label: "Galaxies (NASA)", source: "qrc:/wallpapers/photo-galaxy.jpg" },
        { name: "photo-earth",     label: "Earth (NASA)",    source: "qrc:/wallpapers/photo-earth.jpg" },
        { name: "photo-deepfield", label: "Deep Field (NASA)", source: "qrc:/wallpapers/photo-deepfield.jpg" }
    ]
}
