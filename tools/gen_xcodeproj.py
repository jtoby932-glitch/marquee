#!/usr/bin/env python3
"""Generates MARQUEE.xcodeproj from the folders on disk.

Every .swift file under MARQUEE/ joins the app target, MARQUEETests/ the unit
test target and MARQUEEUITests/ the UI test target. JSON resources, the string
catalog and the asset catalog are bundled. Secrets.swift is always referenced
even though it is gitignored: tools/write_secrets.py creates it before a build.
Re-run after adding or removing files:  python3 tools/gen_xcodeproj.py
"""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = "MARQUEE"
TESTS = "MARQUEETests"
UITESTS = "MARQUEEUITests"
BUNDLE_ID = "com.savonstudios.marquee"
VERSION = "0.1.0"
DEPLOYMENT = "17.0"
SECRETS = Path("MARQUEE/Services/Secrets.swift")
ALT_ICONS = ["AppIcon-Bulbs", "AppIcon-Ticket"]


def uid(*parts):
    return hashlib.md5("/".join(parts).encode()).hexdigest()[:24].upper()


def q(value):
    value = str(value)
    if value and all(c.isalnum() or c in "._/$" for c in value) and not value[0].isdigit():
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def settings(d, indent):
    pad = "\t" * indent
    lines = []
    for key in sorted(d):
        value = d[key]
        if isinstance(value, list):
            inner = "".join(f"\n{pad}\t{q(v)}," for v in value)
            lines.append(f"{pad}{key} = ({inner}\n{pad});")
        else:
            lines.append(f"{pad}{key} = {q(value)};")
    return "\n".join(lines)


FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".json": "text.json",
    ".xcassets": "folder.assetcatalog",
    ".xcstrings": "text.json.xcstrings",
    ".csv": "text",
}


def collect(folder, sources, resources, resource_suffixes):
    for path in sorted((ROOT / folder).rglob("*")):
        rel = path.relative_to(ROOT)
        if any(part.endswith(".xcassets") for part in rel.parts[:-1]):
            continue
        if path.is_dir() and path.suffix == ".xcassets":
            resources.append(rel)
        elif path.is_file() and path.suffix == ".swift":
            sources.append(rel)
        elif path.is_file() and path.suffix in resource_suffixes:
            resources.append(rel)


def build():
    objects = {}

    def add(oid, body):
        objects[oid] = body
        return oid

    app_src, app_res, test_src, test_res, ui_src = [], [], [], [], []
    collect(APP, app_src, app_res, {".json", ".xcstrings"})
    if SECRETS not in app_src:
        app_src.append(SECRETS)
        app_src.sort()
    collect(TESTS, test_src, test_res, {".json", ".csv"})
    collect(UITESTS, ui_src, [], set())

    group_children, group_ids = {}, {}

    def ensure_group(rel_dir):
        key = rel_dir.as_posix()
        if key in group_ids:
            return group_ids[key]
        gid = uid("group", key)
        group_ids[key] = gid
        group_children[key] = []
        if rel_dir.parent.as_posix() != ".":
            ensure_group(rel_dir.parent)
            group_children[rel_dir.parent.as_posix()].append(gid)
        return gid

    for top in (APP, TESTS, UITESTS):
        ensure_group(Path(top))

    file_refs = {}
    for rel in app_src + app_res + test_src + test_res + ui_src:
        ensure_group(rel.parent)
        fid = uid("file", rel.as_posix())
        file_refs[rel.as_posix()] = fid
        group_children[rel.parent.as_posix()].append(fid)
        add(fid, f"isa = PBXFileReference; lastKnownFileType = {q(FILE_TYPES.get(rel.suffix, 'text'))}; path = {q(rel.name)}; sourceTree = \"<group>\";")

    for key, gid in group_ids.items():
        children = "".join(f"\n\t\t\t\t{c}," for c in group_children[key])
        add(gid, f"isa = PBXGroup; children = ({children}\n\t\t\t); path = {q(Path(key).name)}; sourceTree = \"<group>\";")

    products = {
        APP: add(uid("product", APP), f"isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP}.app; sourceTree = BUILT_PRODUCTS_DIR;"),
        TESTS: add(uid("product", TESTS), f"isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {TESTS}.xctest; sourceTree = BUILT_PRODUCTS_DIR;"),
        UITESTS: add(uid("product", UITESTS), f"isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {UITESTS}.xctest; sourceTree = BUILT_PRODUCTS_DIR;"),
    }
    products_group = add(uid("group", "Products"), "isa = PBXGroup; children = (" + "".join(f"\n\t\t\t\t{v}," for v in products.values()) + "\n\t\t\t); name = Products; sourceTree = \"<group>\";")
    main_group = add(uid("group", "main"), "isa = PBXGroup; children = (" + "".join(f"\n\t\t\t\t{group_ids[t]}," for t in (APP, TESTS, UITESTS)) + f"\n\t\t\t\t{products_group},\n\t\t\t); sourceTree = \"<group>\";")

    def phase(isa, key, rels):
        ids = []
        for rel in rels:
            bid = add(uid("build", key, rel.as_posix()), f"isa = PBXBuildFile; fileRef = {file_refs[rel.as_posix()]};")
            ids.append(bid)
        return add(uid("phase", key), f"isa = {isa}; buildActionMask = 2147483647; files = (" + "".join(f"\n\t\t\t\t{i}," for i in ids) + "\n\t\t\t); runOnlyForDeploymentPostprocessing = 0;")

    project_id = uid("project")
    targets = {name: uid("target", name) for name in (APP, TESTS, UITESTS)}

    common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO", "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
        "CLANG_ANALYZER_NONNULL": "YES", "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20", "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES", "COPY_PHASE_STRIP": "NO", "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17", "GCC_NO_COMMON_BLOCKS": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT, "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES", "SDKROOT": "iphoneos",
    }
    project_debug = dict(common, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES", "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_OPTIMIZATION_LEVEL": "0", "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE", "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)", "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    })
    project_release = dict(common, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym", "ENABLE_NS_ASSERTIONS": "NO", "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule", "SWIFT_OPTIMIZATION_LEVEL": "-O", "VALIDATE_PRODUCT": "YES",
    })
    app_settings = {
        "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES": " ".join(ALT_ICONS),
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS": "YES",
        "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_KEY_CFBundleDisplayName": "MARQUEE",
        "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.entertainment",
        "INFOPLIST_KEY_NSCameraUsageDescription": "MARQUEE uses the camera to scan book barcodes.",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_FILE": f"{APP}/Info.plist",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "MARKETING_VERSION": VERSION, "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID, "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
        "SWIFT_EMIT_LOC_STRINGS": "YES", "SWIFT_VERSION": "5.0", "TARGETED_DEVICE_FAMILY": "1",
    }
    test_settings = {
        "BUNDLE_LOADER": "$(TEST_HOST)", "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "YES", "MARKETING_VERSION": VERSION,
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID + ".tests", "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_EMIT_LOC_STRINGS": "NO", "SWIFT_VERSION": "5.0", "TARGETED_DEVICE_FAMILY": "1",
        "TEST_HOST": f"$(BUILT_PRODUCTS_DIR)/{APP}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{APP}",
    }
    ui_settings = {
        "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "GENERATE_INFOPLIST_FILE": "YES",
        "MARKETING_VERSION": VERSION, "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID + ".uitests", "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_EMIT_LOC_STRINGS": "NO", "SWIFT_VERSION": "5.0", "TARGETED_DEVICE_FAMILY": "1", "TEST_TARGET_NAME": APP,
    }

    def config_list(key, debug, release):
        d = add(uid("config", key, "Debug"), f"isa = XCBuildConfiguration; buildSettings = {{\n{settings(debug, 4)}\n\t\t\t}}; name = Debug;")
        r = add(uid("config", key, "Release"), f"isa = XCBuildConfiguration; buildSettings = {{\n{settings(release, 4)}\n\t\t\t}}; name = Release;")
        return add(uid("configlist", key), f"isa = XCConfigurationList; buildConfigurations = (\n\t\t\t\t{d},\n\t\t\t\t{r},\n\t\t\t); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")

    def dependency_on_app(key):
        proxy = add(uid("proxy", key), f"isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {targets[APP]}; remoteInfo = {APP};")
        return add(uid("dependency", key), f"isa = PBXTargetDependency; target = {targets[APP]}; targetProxy = {proxy};")

    def target(name, configs, phases, deps, product_type):
        add(targets[name],
            f"isa = PBXNativeTarget; buildConfigurationList = {configs}; buildPhases = (" + "".join(f"\n\t\t\t\t{p}," for p in phases) + "\n\t\t\t); "
            "buildRules = (\n\t\t\t); dependencies = (" + "".join(f"\n\t\t\t\t{d}," for d in deps) + f"\n\t\t\t); name = {name}; productName = {name}; "
            f"productReference = {products[name]}; productType = \"{product_type}\";")

    target(APP, config_list("app", app_settings, app_settings),
           [phase("PBXSourcesBuildPhase", "app-src", app_src), phase("PBXFrameworksBuildPhase", "app-fw", []), phase("PBXResourcesBuildPhase", "app-res", app_res)],
           [], "com.apple.product-type.application")
    target(TESTS, config_list("tests", test_settings, test_settings),
           [phase("PBXSourcesBuildPhase", "test-src", test_src), phase("PBXFrameworksBuildPhase", "test-fw", []), phase("PBXResourcesBuildPhase", "test-res", test_res)],
           [dependency_on_app("tests")], "com.apple.product-type.bundle.unit-test")
    target(UITESTS, config_list("uitests", ui_settings, ui_settings),
           [phase("PBXSourcesBuildPhase", "ui-src", ui_src), phase("PBXFrameworksBuildPhase", "ui-fw", []), phase("PBXResourcesBuildPhase", "ui-res", [])],
           [dependency_on_app("uitests")], "com.apple.product-type.bundle.ui-testing")

    project_configs = config_list("project", project_debug, project_release)
    t = targets
    add(project_id,
        "isa = PBXProject; attributes = { BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; "
        f"TargetAttributes = {{ {t[APP]} = {{ CreatedOnToolsVersion = 16.0; }}; {t[TESTS]} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {t[APP]}; }}; "
        f"{t[UITESTS]} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {t[APP]}; }}; }}; }}; "
        f"buildConfigurationList = {project_configs}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = \"en-GB\"; hasScannedForEncodings = 0; "
        f"knownRegions = (\n\t\t\t\t\"en-GB\",\n\t\t\t\tBase,\n\t\t\t); mainGroup = {main_group}; productRefGroup = {products_group}; projectDirPath = \"\"; projectRoot = \"\"; "
        f"targets = (\n\t\t\t\t{t[APP]},\n\t\t\t\t{t[TESTS]},\n\t\t\t\t{t[UITESTS]},\n\t\t\t);")

    def isa_of(body):
        return body.split(";", 1)[0].split("=", 1)[1].strip()

    out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};", "\tobjectVersion = 56;", "\tobjects = {"]
    for isa in sorted({isa_of(b) for b in objects.values()}):
        out.append(f"\n/* Begin {isa} section */")
        for oid in sorted(k for k, b in objects.items() if isa_of(b) == isa):
            out.append(f"\t\t{oid} = {{{objects[oid]}}};")
        out.append(f"/* End {isa} section */")
    out += ["\t};", f"\trootObject = {project_id};", "}", ""]

    proj = ROOT / f"{APP}.xcodeproj"
    (proj / "project.xcworkspace").mkdir(parents=True, exist_ok=True)
    (proj / "project.pbxproj").write_text("\n".join(out))
    (proj / "project.xcworkspace" / "contents.xcworkspacedata").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version = "1.0">\n   <FileRef location = "self:">\n   </FileRef>\n</Workspace>\n')
    write_scheme(proj, targets)
    print(f"{len(app_src)} app sources, {len(app_res)} resources, {len(test_src)} unit test files, {len(ui_src)} UI test files")


def write_scheme(proj, targets):
    schemes = proj / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)

    def ref(name, product):
        return (f'<BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{targets[name]}" '
                f'BuildableName = "{product}" BlueprintName = "{name}" ReferencedContainer = "container:{APP}.xcodeproj"></BuildableReference>')

    app_ref = ref(APP, f"{APP}.app")
    testables = "".join(
        f'\n         <TestableReference skipped = "NO" parallelizable = "NO">\n            {ref(n, n + ".xctest")}\n         </TestableReference>'
        for n in (TESTS, UITESTS))
    (schemes / f"{APP}.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            {app_ref}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>{testables}
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         {app_ref}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         {app_ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
''')


if __name__ == "__main__":
    build()
