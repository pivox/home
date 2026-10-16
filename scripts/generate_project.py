#!/usr/bin/env python3
"""Rebuild the small Xcode project deterministically; no XcodeGen dependency."""
from pathlib import Path
import hashlib
import argparse
import plistlib

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path, default=ROOT, help='Destination root, for non-mutating validation')
args = parser.parse_args()
def uid(key):
    return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def quote(value):
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
def settings(values):
    return '{ ' + ' '.join(f'{key} = {quote(value)};' for key, value in values.items()) + ' }'

objects = []
def add(key, content):
    objects.append(f'\t\t{uid(key)} = {{ {content} }};')

sources = ['ADeuxApp.swift', 'AppServices.swift', 'ShareInvitationDelegate.swift', 'CloudSharingSheet.swift']
for filename in sources:
    add('file.' + filename, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(filename)}; sourceTree = "<group>";')
    add('build.' + filename, f'isa = PBXBuildFile; fileRef = {uid("file." + filename)};')
for filename, kind in [('Info.plist', 'text.plist.xml'), ('ADeux.entitlements', 'text.plist.entitlements'), ('Local.entitlements', 'text.plist.entitlements'), ('Assets.xcassets', 'folder.assetcatalog')]:
    add('file.' + filename, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {quote(filename)}; sourceTree = "<group>";')
add('build.assets', f'isa = PBXBuildFile; fileRef = {uid("file.Assets.xcassets")};')
add('app.group', 'isa = PBXGroup; children = (' + ','.join(uid('file.' + f) for f in sources + ['Info.plist','ADeux.entitlements','Local.entitlements','Assets.xcassets']) + ',); path = App; sourceTree = "<group>";')
for path in ['Sources', 'Tests', 'docs', 'Package.swift', 'README.md']:
    kind = 'sourcecode.swift' if path.endswith('.swift') else 'net.daringfireball.markdown' if path.endswith('.md') else 'folder'
    add('ref.' + path, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {quote(path)}; sourceTree = "<group>";')
add('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ADeux.app; sourceTree = BUILT_PRODUCTS_DIR;')
add('products', f'isa = PBXGroup; children = ({uid("product")},); name = Products; sourceTree = "<group>";')
add('config.file', 'isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Config/Project.xcconfig; sourceTree = "<group>";')
add('main.group', 'isa = PBXGroup; children = (' + ','.join([uid('app.group'), uid('config.file')] + [uid('ref.'+p) for p in ['Sources','Tests','docs','Package.swift','README.md']] + [uid('products')]) + ',); sourceTree = "<group>";')
add('source.phase', 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (' + ','.join(uid('build.'+s) for s in sources) + ',); runOnlyForDeploymentPostprocessing = 0;')
add('resources.phase', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({uid("build.assets")},); runOnlyForDeploymentPostprocessing = 0;')
products = ['DeuxCore','DeuxPersistence','DeuxUI','DeuxNotifications']
for product in products:
    add('package.' + product, f'isa = XCSwiftPackageProductDependency; package = {uid("local.package")}; productName = {product};')
    add('link.' + product, f'isa = PBXBuildFile; productRef = {uid("package."+product)};')
add('frameworks.phase', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (' + ','.join(uid('link.'+p) for p in products) + ',); runOnlyForDeploymentPostprocessing = 0;')
add('local.package', 'isa = XCLocalSwiftPackageReference; relativePath = .;')
add('target', f'isa = PBXNativeTarget; buildConfigurationList = {uid("target.configlist")}; buildPhases = ({uid("source.phase")},{uid("frameworks.phase")},{uid("resources.phase")},); buildRules = (); dependencies = (); name = ADeux; packageProductDependencies = (' + ','.join(uid('package.'+p) for p in products) + f',); productName = ADeux; productReference = {uid("product")}; productType = "com.apple.product-type.application";')
configs = ['Debug','Release','Debug-iCloud','Release-iCloud']
for config in configs:
    release = config.startswith('Release')
    cloud = 'iCloud' in config
    project = {
        'ALWAYS_SEARCH_USER_PATHS':'NO', 'CLANG_ENABLE_MODULES':'YES', 'CLANG_ENABLE_OBJC_ARC':'YES',
        'IPHONEOS_DEPLOYMENT_TARGET':'17.0', 'SDKROOT':'iphoneos', 'SWIFT_VERSION':'5.0',
        'SWIFT_OPTIMIZATION_LEVEL':'-O' if release else '-Onone',
        'SWIFT_COMPILATION_MODE':'wholemodule' if release else 'singlefile',
        'ENABLE_TESTABILITY':'NO' if release else 'YES',
        'DEBUG_INFORMATION_FORMAT':'dwarf-with-dsym' if release else 'dwarf',
        'ONLY_ACTIVE_ARCH':'NO' if release else 'YES',
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'$(inherited)' if release else '$(inherited) DEBUG',
    }
    target = {
        'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon', 'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor',
        'CODE_SIGN_STYLE':'Automatic', 'CODE_SIGN_ENTITLEMENTS':'App/ADeux.entitlements' if cloud else 'App/Local.entitlements',
        'CURRENT_PROJECT_VERSION':'1', 'MARKETING_VERSION':'0.1.0', 'GENERATE_INFOPLIST_FILE':'NO',
        'INFOPLIST_FILE':'App/Info.plist', 'PRODUCT_NAME':'$(TARGET_NAME)',
        'SUPPORTED_PLATFORMS':'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST':'NO', 'TARGETED_DEVICE_FAMILY':'1',
        'ADEUX_CLOUD_ENABLED':'YES' if cloud else 'NO',
        'APS_ENVIRONMENT':'production' if release else 'development', 'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks',
        'SWIFT_EMIT_LOC_STRINGS':'YES', 'ENABLE_PREVIEWS':'YES',
    }
    add('project.config.'+config, f'isa = XCBuildConfiguration; buildSettings = {settings(project)}; name = {quote(config)};')
    add('target.config.'+config, f'isa = XCBuildConfiguration; baseConfigurationReference = {uid("config.file")}; buildSettings = {settings(target)}; name = {quote(config)};')
for kind in ['project','target']:
    add(kind+'.configlist', f'isa = XCConfigurationList; buildConfigurations = (' + ','.join(uid(kind+'.config.'+c) for c in configs) + ',); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
add('project', f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {uid("target")} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {uid("project.configlist")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = fr; hasScannedForEncodings = 0; knownRegions = (fr,en,Base,); mainGroup = {uid("main.group")}; packageReferences = ({uid("local.package")},); productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")},);')
project_dir = args.output_dir.resolve()/'ADeux.xcodeproj'
project_dir.mkdir(exist_ok=True)
(project_dir/'project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n'+'\n'.join(objects)+'\n\t};\n\trootObject = '+uid('project')+';\n}\n')
for name, debug, release in [('ADeux','Debug','Release'),('ADeux-iCloud','Debug-iCloud','Release-iCloud')]:
    directory = project_dir/'xcshareddata/xcschemes'
    directory.mkdir(parents=True, exist_ok=True)
    ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target")}" BuildableName="ADeux.app" BlueprintName="ADeux" ReferencedContainer="container:ADeux.xcodeproj"/>'
    (directory/(name+'.xcscheme')).write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="{debug}" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
 <LaunchAction buildConfiguration="{debug}" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="{release}" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="{debug}"/>
 <ArchiveAction buildConfiguration="{release}" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print('Generated ADeux.xcodeproj (local + iCloud schemes).')
