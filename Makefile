TARGET := iphone:clang:latest:15.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES := TikTok

# Rootless jailbreaks install under /var/jb. Sideload injection uses the
# dylib inside the package; cyan rewrites the substrate dependency.
export THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := TikSpice

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
	src/Floater.m \
	src/SettingsUI.m \
	src/Playback.xm \
	src/Interface.xm \
	src/PrivateHooks.xm \
	src/Tweak.xm

TikSpice_CFLAGS := -fobjc-arc -Isrc -Wno-deprecated-declarations -Wno-unused-function -Wno-nullability-completeness
TikSpice_FRAMEWORKS := UIKit Foundation AVFoundation Photos UniformTypeIdentifiers CoreGraphics QuartzCore
TikSpice_LIBRARIES := substrate

include $(THEOS_MAKE_PATH)/tweak.mk
