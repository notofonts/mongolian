SOURCES=$(shell python3 scripts/read-config.py --sources | sed 's/[^a-zA-Z._\/ ]//')
help:
	@echo "###"
	@echo "# Build targets"
	@echo "###"
	@echo
	@echo "  make build:  Builds the fonts and places them in the fonts/ directory"
	@echo "  make test:   Tests the fonts with fontbakery"
	@echo "  make shaping: Checks the source against the Mongolian test suites"
	@echo "  make proof:  Creates HTML proof documents in the proof/ directory"
	@echo "  make images: Creates PNG specimen images in the documentation/ directory"
	@echo

build: build.stamp

venv: venv/touchfile

build.stamp: venv .init.stamp sources/config*.yaml $(SOURCES)
	rm -rf fonts
	(for config in sources/config*.yaml; do . venv/bin/activate; gftools-builder $$config; done)  && touch build.stamp

.init.stamp: venv
	. venv/bin/activate; python3 scripts/first-run.py

venv/touchfile: requirements.txt
	test -d venv || python3 -m venv venv
	. venv/bin/activate; pip install -Ur requirements.txt
	touch venv/touchfile

test: venv build.stamp shaping
	. venv/bin/activate; python3 -m notoqa

# The Mongolian test suites: the EAC suite of Hudum and the suites of the Chinese national
# standard, shaped against the build this project ships
# (fonts/NotoSansMongolian/googlefonts, the one that merges the Latin core of includeSubsets).
# The first run checks the font against what the standard settles; the second checks the
# expectations stored in qa/shaping_tests/ with fontspector. Regenerate the expectations with
# `python scripts/gen_shaping_tests.py --write --conformant-only` after a change to shaping,
# and refresh a hand-written file with `python scripts/gen_shaping_tests.py --refresh FILE`.
shaping: venv build.stamp
	. venv/bin/activate; python3 scripts/gen_shaping_tests.py
	. venv/bin/activate; fontspector --configuration fontspector.json --profile googlefonts -c shaping fonts/NotoSansMongolian/googlefonts/ttf/*.ttf

proof: venv build.stamp
	. venv/bin/activate; mkdir -p out/ out/proof; gftools gen-html proof $(shell find fonts/*/unhinted/ttf -type f) -o out/proof

%.png: %.py build.stamp
	python3 $< --output $@

clean:
	rm -rf venv
	find . -name "*.pyc" | xargs rm delete

update-ufr:
	npx update-template https://github.com/notofonts/noto-project-template/

update:
	pip install --upgrade $(dependency)

manual_release: build.stamp
	@echo "Creating release files manually is contraindicated."
	@echo "Please use the CI for releases instead."
	cd fonts; for family in *; do VERSION=`font-v report $$family/unhinted/ttf/* | grep Version | sort -u  | awk '{print $$2}'`; zip -r ../$$family-v$$VERSION.zip $$family; done

