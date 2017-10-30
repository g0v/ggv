PDF_VIEWER_SRC=../../pdf.js-hypothes.is

UNAME_S=$(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	REPLACE_JS_SRC=sed -i '' 's/.*embed\.js.*/  <script src="http:\/\/localhost:3001\/hypothesis\/1.48.0\/build\/boot.js"><\/script>/' ./viewer/web/viewer.html
else
	REPLACE_JS_SRC=sed -i 's/.*embed\.js.*/  <script src="http:\/\/localhost:3001\/hypothesis\/1.48.0\/build\/boot.js"><\/script>/' ./viewer/web/viewer.html
endif

.PHONY: default
default: all

.PHONY: all
all: viewer

.PHONY: clean
clean:
	rm -r ./viewer

viewer: $(PDF_VIEWER_SRC)/viewer/web/viewer.html
	rsync -au $(PDF_VIEWER_SRC)/viewer/* ./viewer
	$(REPLACE_JS_SRC)
