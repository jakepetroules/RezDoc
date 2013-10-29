SRCROOT=.
BLDROOT=Build
TSTROOT=$(SRCROOT)/Tests

all:
	mkdir -p $(BLDROOT)
	xcrun -sdk macosx clang -arch i386 -arch x86_64 -mmacosx-version-min=10.4 -Wall -Werror -o $(BLDROOT)/RezDoc $(SRCROOT)/RezDoc/main.m -framework Cocoa

check:	all
	$(BLDROOT)/RezDoc $(TSTROOT)/test.doc $(BLDROOT)/test.doc.r 5000
	@echo "=== Word 97 Document ==="
	cat $(BLDROOT)/test.doc.r

	$(BLDROOT)/RezDoc $(TSTROOT)/test.docx $(BLDROOT)/test.docx.r 5000
	@echo "=== Word 2007 Document ==="
	cat $(BLDROOT)/test.docx.r

	$(BLDROOT)/RezDoc $(TSTROOT)/test.odt $(BLDROOT)/test.odt.r 5000
	@echo "=== OpenDocument Text Document ==="
	cat $(BLDROOT)/test.odt.r

	$(BLDROOT)/RezDoc $(TSTROOT)/test.rtf $(BLDROOT)/test.rtf.r 5000
	@echo "=== Rich Text Document ==="
	cat $(BLDROOT)/test.rtf.r

	$(BLDROOT)/RezDoc $(TSTROOT)/test.txt $(BLDROOT)/test.txt.r 5000
	@echo "=== Plain Text Document ==="
	cat $(BLDROOT)/test.txt.r

	$(BLDROOT)/RezDoc $(TSTROOT)/test.xml $(BLDROOT)/test.xml.r 5000
	@echo "=== Word 2003 Document ==="
	cat $(BLDROOT)/test.xml.r

clean:
	rm -rf $(BLDROOT)
