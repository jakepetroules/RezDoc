SRCROOT=.
BLDROOT=Build
TSTROOT=$(SRCROOT)/Tests

all:
	mkdir -p $(BLDROOT)
	xcrun -sdk macosx clang -arch i386 -arch x86_64 -mmacosx-version-min=10.4 -Wall -Werror -o $(BLDROOT)/RezDoc $(SRCROOT)/RezDoc/main.m -framework Cocoa

check:	all
	$(BLDROOT)/RezDoc -l -o $(BLDROOT)/test.doc.r English $(TSTROOT)/test.doc
	@echo "=== Word 97 Document ==="
	cat $(BLDROOT)/test.doc.r

	$(BLDROOT)/RezDoc -l -o $(BLDROOT)/test.docx.r German $(TSTROOT)/test.docx
	@echo "=== Word 2007 Document ==="
	cat $(BLDROOT)/test.docx.r

	$(BLDROOT)/RezDoc -l -o $(BLDROOT)/test.odt.r en $(TSTROOT)/test.odt
	@echo "=== OpenDocument Text Document ==="
	cat $(BLDROOT)/test.odt.r

	$(BLDROOT)/RezDoc -l -o $(BLDROOT)/test.rtf.r fr_CA $(TSTROOT)/test.rtf
	@echo "=== Rich Text Document ==="
	cat $(BLDROOT)/test.rtf.r

	$(BLDROOT)/RezDoc -l -o $(BLDROOT)/test.txt.r Japanese $(TSTROOT)/test.txt
	@echo "=== Plain Text Document ==="
	cat $(BLDROOT)/test.txt.r

	$(BLDROOT)/RezDoc -l -o $(BLDROOT)/test2.txt.r en $(TSTROOT)/test.txt
	@echo "=== Plain Text Document ==="
	cat $(BLDROOT)/test2.txt.r
    
	$(BLDROOT)/RezDoc -o $(BLDROOT)/test3.txt.r en $(TSTROOT)/test.txt
	@echo "=== Plain Text Document ==="
	cat $(BLDROOT)/test3.txt.r

	$(BLDROOT)/RezDoc -l -o $(BLDROOT)/test.xml.r zh_CN $(TSTROOT)/test.xml
	@echo "=== Word 2003 Document ==="
	cat $(BLDROOT)/test.xml.r

	$(BLDROOT)/RezDoc -l -o $(BLDROOT)/test.r $(TSTROOT)/licenses.plist
	cat $(BLDROOT)/test.r

clean:
	rm -rf $(BLDROOT)
