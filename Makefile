THEOS_DEVICE_IP = 192.168.1.100
THEOS_PACKAGE_SCHEME = rootless

TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

TWEAK_NAME = WhatsAppBizMulti

WhatsAppBizMulti_FILES = Tweak.xm
WhatsAppBizMulti_CFLAGS = -fobjc-arc
WhatsAppBizMulti_FRAMEWORKS = UIKit CoreLocation
WhatsAppBizMulti_PRIVATE_FRAMEWORKS = AppSupport
WhatsAppBizMulti_LIBRARIES = substrate

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += WhatsAppBizMulti
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 WhatsApp\ Business"
