TARGET           := iphone:clang:16.5:15.0
ARCHS            := arm64
INSTALL_TARGET_PROCESSES := AppDataKit

# TrollStore distribution: rootful layout (/Applications/AppDataKit.app inside the deb).
# TrollStore reads the .tipa, ignores the deb scaffolding, and installs the .app to
# /var/containers/Bundle/Application/<UUID>/ on the device.
THEOS_DEVICE_IP ?=

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AppDataKit

AppDataKit_FILES = \
	Sources/main.m \
	Sources/ADKAppDelegate.m \
	Sources/UI/Cells/ADKAppCell.m \
	Sources/UI/Controllers/ADKAppListViewController.m \
	Sources/UI/Controllers/ADKBackupListViewController.m \
	Sources/UI/Controllers/ADKOperationProgressViewController.m \
	Sources/UI/Controllers/ADKSettingsViewController.m \
	Sources/UI/Views/ADKEmptyStateView.m \
	Sources/Managers/ADKAppRepository.m \
	Sources/Managers/ADKBackupManager.m \
	Sources/Managers/ADKRestoreManager.m \
	Sources/Managers/ADKWipeManager.m \
	Sources/Managers/ADKBatchCoordinator.m \
	Sources/Managers/ADKSelectionState.m \
	Sources/Cache/ADKIconCache.m \
	Sources/Models/ADKApp.m \
	Sources/Models/ADKBackup.m \
	Sources/Helpers/ADKFileSystem.m \
	Sources/Helpers/ADKZipRunner.m \
	Sources/Helpers/ADKAdbkPackager.m \
	Sources/Helpers/ADKByteFormatter.m \
	Sources/Helpers/ADKLSWorkspace.m

AppDataKit_FRAMEWORKS = UIKit CoreGraphics QuartzCore Foundation ImageIO
AppDataKit_PRIVATE_FRAMEWORKS =

# Theos only adds the .m file's own directory to the header search path; any
# `#import "Foo.h"` that crosses subfolders (Sources/UI/Cells -> Sources/Models)
# needs an explicit -I. Listing every leaf folder is the simplest fix.
AppDataKit_CFLAGS = -fobjc-arc \
  -Wno-deprecated-declarations \
  -Wno-unguarded-availability-new \
  -ISources \
  -ISources/UI \
  -ISources/UI/Cells \
  -ISources/UI/Controllers \
  -ISources/UI/Views \
  -ISources/Managers \
  -ISources/Cache \
  -ISources/Models \
  -ISources/Helpers

AppDataKit_LDFLAGS = -Wl,-segalign,4000
AppDataKit_CODESIGN_FLAGS = -SResources/Entitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

after-package::
	@echo "==> Producing .tipa from .deb"
	@mkdir -p packages
	@DEB=$$(ls -t packages/*.deb | head -n1); \
	  TMP=$$(mktemp -d); \
	  dpkg-deb -R "$$DEB" "$$TMP"; \
	  mkdir -p "$$TMP/Payload"; \
	  cp -R "$$TMP/Applications/AppDataKit.app" "$$TMP/Payload/"; \
	  (cd "$$TMP" && zip -qr "$(PWD)/packages/AppDataKit.tipa" Payload); \
	  rm -rf "$$TMP"; \
	  echo "==> Wrote packages/AppDataKit.tipa"
