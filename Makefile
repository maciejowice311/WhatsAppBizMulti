THEOS_PACKAGE_SCHEME = rootless

TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

TWEAK_NAME = WhatsAppBizMulti

WhatsAppBizMulti_FILES = Tweak.xm
WhatsAppBizMulti_CFLAGS = -fobjc-arc -Wno-unused-function
WhatsAppBizMulti_FRAMEWORKS = UIKit CoreLocation

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 WhatsApp\ Business"
