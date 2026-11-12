TARGET := iphone:clang:latest:15.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES := TikTok

# Rootless package layout for a jailbreak install. The dylib itself does not
# link CydiaSubstrate or ElleKit; Logos uses the Objective-C runtime so
# LiveContainer can dlopen the file with no extra libraries.
export THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := TikSpice

TikSpice_LOGOS_DEFAULT_GENERATOR := internal

TikSpice_FILES := \
	src/TSKeys.m \
	src/Prefs.m \
	src/Theme.m \
	src/HookRegistry.m \
	src/Chrome.m \
	src/Scanner.m \
	src/UIUtil.m \
	src/Download.m \
	src/PlaybackGate.m \
	src/Entry.m \
	src/SettingsUI.m \
	src/Playback.xm \
	src/Interface.xm \
	src/PrivateHooks.xm \
	src/Tweak.xm

TikSpice_CFLAGS := -fobjc-arc -Isrc -Wno-deprecated-declarations -Wno-unused-function -Wno-nullability-completeness
TikSpice_FRAMEWORKS := UIKit Foundation AVFoundation Photos UniformTypeIdentifiers CoreGraphics QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
