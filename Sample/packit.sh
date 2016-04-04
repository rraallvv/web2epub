#!/bin/bash
rm ../Sample.epub
zip -X ../Sample.epub mimetype
zip -rg ../Sample.epub META-INF -x \*.DS_Store
zip -rg ../Sample.epub OEBPS -x \*.DS_Store