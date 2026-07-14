#!/bin/bash
# ===========================================================================
# SwiftBook - Xcode Project Generator
# Creates a ready-to-build Xcode project for the EPUB reader app.
# ===========================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/SwiftBook"
XCODEPROJ_DIR="$PROJECT_DIR/SwiftBook.xcodeproj"

echo "📚 SwiftBook - 项目生成器"
echo "=========================="
echo ""

# ── Check for XcodeGen (preferred) ──────────────────────────────────
if command -v xcodegen &> /dev/null; then
    echo "✅ 检测到 XcodeGen，使用 project.yml 生成项目..."
    cd "$PROJECT_DIR"
    xcodegen generate --spec project.yml
    echo ""
    echo "🎉 项目生成成功！"
    echo "   打开方式: open $XCODEPROJ_DIR"
    exit 0
fi

# ── Manual Xcode project generation ──────────────────────────────────
echo "ℹ️  未检测到 XcodeGen，将手动创建 Xcode 项目..."
echo "   (推荐安装 XcodeGen: brew install xcodegen)"
echo ""

# Generate UUIDs
uuid() {
    uuidgen | tr '[:lower:]' '[:upper:]' | tr -d '-' | cut -c1-24
}

# Project-level IDs
PROJ_ID=$(uuid)
ROOT_GROUP_ID=$(uuid)
SOURCES_GROUP_ID=$(uuid)
APP_GROUP_ID=$(uuid)
MODELS_GROUP_ID=$(uuid)
VIEWS_GROUP_ID=$(uuid)
SERVICES_GROUP_ID=$(uuid)
UTILITIES_GROUP_ID=$(uuid)
RESOURCES_GROUP_ID=$(uuid)
PRODUCTS_GROUP_ID=$(uuid)
PRODUCT_REF_ID=$(uuid)

# Build settings IDs
BUILD_CONFIG_LIST_ID=$(uuid)
BUILD_CONFIG_DEBUG_ID=$(uuid)
BUILD_CONFIG_RELEASE_ID=$(uuid)

# Target IDs
TARGET_ID=$(uuid)
TARGET_CONFIG_LIST_ID=$(uuid)
TARGET_CONFIG_DEBUG_ID=$(uuid)
TARGET_CONFIG_RELEASE_ID=$(uuid)
TARGET_BUILD_PHASE_SOURCES_ID=$(uuid)
TARGET_BUILD_PHASE_RESOURCES_ID=$(uuid)
TARGET_PRODUCT_REF_ID=$(uuid)

# File ref IDs - Sources
FILE_REF_APP_ID=$(uuid)
FILE_REF_BOOK_ID=$(uuid)
FILE_REF_SETTINGS_ID=$(uuid)
FILE_REF_LIBRARY_ID=$(uuid)
FILE_REF_READER_ID=$(uuid)
FILE_REF_SETTINGSPANEL_ID=$(uuid)
FILE_REF_BOOKCARD_ID=$(uuid)
FILE_REF_BOOKMANAGER_ID=$(uuid)
FILE_REF_EPUBPARSER_ID=$(uuid)
FILE_REF_VOLUMEBUTTON_ID=$(uuid)
FILE_REF_ZIPREADER_ID=$(uuid)
FILE_REF_CONTENTVIEW_ID=$(uuid)

# Build file IDs — MUST be unique (different from FileRef IDs!)
BF_APP_ID=$(uuid)
BF_BOOK_ID=$(uuid)
BF_SETTINGS_ID=$(uuid)
BF_LIBRARY_ID=$(uuid)
BF_READER_ID=$(uuid)
BF_SETTINGSPANEL_ID=$(uuid)
BF_BOOKCARD_ID=$(uuid)
BF_BOOKMANAGER_ID=$(uuid)
BF_EPUBPARSER_ID=$(uuid)
BF_VOLUMEBUTTON_ID=$(uuid)
BF_ZIPREADER_ID=$(uuid)

# Frameworks build phase ID
TARGET_BUILD_PHASE_FRAMEWORKS_ID=$(uuid)

# Create directory structure
mkdir -p "$XCODEPROJ_DIR"

# ── Generate project.pbxproj ─────────────────────────────────────────
PBXPROJ="$XCODEPROJ_DIR/project.pbxproj"

cat > "$PBXPROJ" << PBXEOF
// !\$*UTF8*\$!
{
	archiveVersion = 1;
	classes = {};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		$BF_APP_ID /* SwiftBookApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_APP_ID; };
		$BF_BOOK_ID /* Book.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_BOOK_ID; };
		$BF_SETTINGS_ID /* ReadingSettings.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_SETTINGS_ID; };
		$BF_LIBRARY_ID /* LibraryView.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_LIBRARY_ID; };
		$BF_READER_ID /* ReaderView.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_READER_ID; };
		$BF_SETTINGSPANEL_ID /* SettingsPanelView.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_SETTINGSPANEL_ID; };
		$BF_BOOKCARD_ID /* BookCardView.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_BOOKCARD_ID; };
		$BF_BOOKMANAGER_ID /* BookManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_BOOKMANAGER_ID; };
		$BF_EPUBPARSER_ID /* EPUBParser.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_EPUBPARSER_ID; };
		$BF_VOLUMEBUTTON_ID /* VolumeButtonHandler.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_VOLUMEBUTTON_ID; };
		$BF_ZIPREADER_ID /* ZipReader.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_ZIPREADER_ID; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		$FILE_REF_APP_ID /* SwiftBookApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SwiftBookApp.swift; sourceTree = "<group>"; };
		$FILE_REF_BOOK_ID /* Book.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Book.swift; sourceTree = "<group>"; };
		$FILE_REF_SETTINGS_ID /* ReadingSettings.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ReadingSettings.swift; sourceTree = "<group>"; };
		$FILE_REF_LIBRARY_ID /* LibraryView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LibraryView.swift; sourceTree = "<group>"; };
		$FILE_REF_READER_ID /* ReaderView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ReaderView.swift; sourceTree = "<group>"; };
		$FILE_REF_SETTINGSPANEL_ID /* SettingsPanelView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SettingsPanelView.swift; sourceTree = "<group>"; };
		$FILE_REF_BOOKCARD_ID /* BookCardView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BookCardView.swift; sourceTree = "<group>"; };
		$FILE_REF_BOOKMANAGER_ID /* BookManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BookManager.swift; sourceTree = "<group>"; };
		$FILE_REF_EPUBPARSER_ID /* EPUBParser.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = EPUBParser.swift; sourceTree = "<group>"; };
		$FILE_REF_VOLUMEBUTTON_ID /* VolumeButtonHandler.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = VolumeButtonHandler.swift; sourceTree = "<group>"; };
		$FILE_REF_ZIPREADER_ID /* ZipReader.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ZipReader.swift; sourceTree = "<group>"; };
		$TARGET_PRODUCT_REF_ID /* SwiftBook.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SwiftBook.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		$TARGET_BUILD_PHASE_FRAMEWORKS_ID /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = ();
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		$ROOT_GROUP_ID = {
			isa = PBXGroup;
			children = (
				$SOURCES_GROUP_ID /* Sources */,
				$PRODUCTS_GROUP_ID /* Products */,
			);
			sourceTree = "<group>";
		};
		$SOURCES_GROUP_ID /* Sources */ = {
			isa = PBXGroup;
			children = (
				$APP_GROUP_ID /* App */,
				$MODELS_GROUP_ID /* Models */,
				$VIEWS_GROUP_ID /* Views */,
				$SERVICES_GROUP_ID /* Services */,
				$UTILITIES_GROUP_ID /* Utilities */,
				$RESOURCES_GROUP_ID /* Resources */,
			);
			path = Sources;
			sourceTree = "<group>";
		};
		$APP_GROUP_ID /* App */ = {
			isa = PBXGroup;
			children = (
				$FILE_REF_APP_ID /* SwiftBookApp.swift */,
			);
			path = App;
			sourceTree = "<group>";
		};
		$MODELS_GROUP_ID /* Models */ = {
			isa = PBXGroup;
			children = (
				$FILE_REF_BOOK_ID /* Book.swift */,
				$FILE_REF_SETTINGS_ID /* ReadingSettings.swift */,
			);
			path = Models;
			sourceTree = "<group>";
		};
		$VIEWS_GROUP_ID /* Views */ = {
			isa = PBXGroup;
			children = (
				$FILE_REF_LIBRARY_ID /* LibraryView.swift */,
				$FILE_REF_READER_ID /* ReaderView.swift */,
				$FILE_REF_SETTINGSPANEL_ID /* SettingsPanelView.swift */,
				$FILE_REF_BOOKCARD_ID /* BookCardView.swift */,
			);
			path = Views;
			sourceTree = "<group>";
		};
		$SERVICES_GROUP_ID /* Services */ = {
			isa = PBXGroup;
			children = (
				$FILE_REF_BOOKMANAGER_ID /* BookManager.swift */,
				$FILE_REF_EPUBPARSER_ID /* EPUBParser.swift */,
				$FILE_REF_VOLUMEBUTTON_ID /* VolumeButtonHandler.swift */,
			);
			path = Services;
			sourceTree = "<group>";
		};
		$UTILITIES_GROUP_ID /* Utilities */ = {
			isa = PBXGroup;
			children = (
				$FILE_REF_ZIPREADER_ID /* ZipReader.swift */,
			);
			path = Utilities;
			sourceTree = "<group>";
		};
		$RESOURCES_GROUP_ID /* Resources */ = {
			isa = PBXGroup;
			children = (
			);
			path = Resources;
			sourceTree = "<group>";
		};
		$PRODUCTS_GROUP_ID /* Products */ = {
			isa = PBXGroup;
			children = (
				$TARGET_PRODUCT_REF_ID /* SwiftBook.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		$TARGET_ID /* SwiftBook */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = $TARGET_CONFIG_LIST_ID;
			buildPhases = (
				$TARGET_BUILD_PHASE_SOURCES_ID /* Sources */,
				$TARGET_BUILD_PHASE_FRAMEWORKS_ID /* Frameworks */,
				$TARGET_BUILD_PHASE_RESOURCES_ID /* Resources */,
			);
			buildRules = ();
			dependencies = ();
			name = SwiftBook;
			productName = SwiftBook;
			productReference = $TARGET_PRODUCT_REF_ID;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		$PROJ_ID /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {
					$TARGET_ID = {
						CreatedOnToolsVersion = 15.0;
					};
				};
			};
			buildConfigurationList = $BUILD_CONFIG_LIST_ID;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = "zh-Hans";
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				"zh-Hans",
				Base,
			);
			mainGroup = $ROOT_GROUP_ID;
			productRefGroup = $PRODUCTS_GROUP_ID;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				$TARGET_ID /* SwiftBook */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		$TARGET_BUILD_PHASE_RESOURCES_ID /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = ();
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		$TARGET_BUILD_PHASE_SOURCES_ID /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				$BF_APP_ID /* SwiftBookApp.swift in Sources */,
				$BF_BOOK_ID /* Book.swift in Sources */,
				$BF_SETTINGS_ID /* ReadingSettings.swift in Sources */,
				$BF_LIBRARY_ID /* LibraryView.swift in Sources */,
				$BF_READER_ID /* ReaderView.swift in Sources */,
				$BF_SETTINGSPANEL_ID /* SettingsPanelView.swift in Sources */,
				$BF_BOOKCARD_ID /* BookCardView.swift in Sources */,
				$BF_BOOKMANAGER_ID /* BookManager.swift in Sources */,
				$BF_EPUBPARSER_ID /* EPUBParser.swift in Sources */,
				$BF_VOLUMEBUTTON_ID /* VolumeButtonHandler.swift in Sources */,
				$BF_ZIPREADER_ID /* ZipReader.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		$BUILD_CONFIG_DEBUG_ID /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"\$(inherited)",
				);
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		$BUILD_CONFIG_RELEASE_ID /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_OPTIMIZATION_LEVEL = s;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		$TARGET_CONFIG_DEBUG_ID /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = Sources/Resources/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = SwiftBook;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"\$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.swiftbook.reader;
				PRODUCT_NAME = "\$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		$TARGET_CONFIG_RELEASE_ID /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = Sources/Resources/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = SwiftBook;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"\$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.swiftbook.reader;
				PRODUCT_NAME = "\$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		$BUILD_CONFIG_LIST_ID /* Build configuration list for PBXProject */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				$BUILD_CONFIG_DEBUG_ID /* Debug */,
				$BUILD_CONFIG_RELEASE_ID /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		$TARGET_CONFIG_LIST_ID /* Build configuration list for PBXNativeTarget */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				$TARGET_CONFIG_DEBUG_ID /* Debug */,
				$TARGET_CONFIG_RELEASE_ID /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

	};
	rootObject = $PROJ_ID /* Project object */;
}
PBXEOF

echo "✅ 项目文件已生成: $XCODEPROJ_DIR"
echo ""
echo "🎉 项目创建完成！"
echo ""
echo "📋 下一步："
echo "   1. 用 Xcode 打开项目:"
echo "      open $XCODEPROJ_DIR"
echo ""
echo "   2. 在 Xcode 中选择你的开发团队"
echo "      (Target → Signing & Capabilities → Team)"
echo ""
echo "   3. 连接 iPhone 或选择模拟器，点击运行 ▶️"
echo ""
echo "📱 最低要求: iOS 16.0+"
echo "📖 支持的格式: EPUB (.epub)"
