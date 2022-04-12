## Customize Makefile settings for fbdv
##
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile

DATE   ?= $(shell date +%Y-%m-%d)

# Using .SECONDEXPANSION to include custom FlyBase files in $(ASSETS). Also rsyncing $(IMPORTS) and $(REPORT_FILES).
.SECONDEXPANSION:
.PHONY: prepare_release
prepare_release: $$(ASSETS) release_reports
	rsync -R $(ASSETS) $(RELEASEDIR) &&\
	rm -f $(CLEANFILES) &&\
	echo "Release files are now in $(RELEASEDIR) - now you should commit, push and make a release on your git hosting site such as GitHub or GitLab"

MAIN_FILES := $(MAIN_FILES) fly_development.obo
CLEANFILES := $(CLEANFILES) $(patsubst %, $(IMPORTDIR)/%_terms_combined.txt, $(IMPORTS))

######################################################
### Code for generating additional FlyBase reports ###
######################################################

FLYBASE_REPORTS = reports/obo_qc_fbdv.obo.txt reports/obo_qc_fbdv.owl.txt reports/obo_track_new_simple.txt reports/robot_simple_diff.txt reports/onto_metrics_calc.txt reports/chado_load_check_simple.txt

.PHONY: flybase_reports
flybase_reports: $(FLYBASE_REPORTS)

.PHONY: all_reports
all_reports: custom_reports robot_reports flybase_reports

.PHONY: release_reports
release_reports: robot_reports flybase_reports

SIMPLE_PURL =	http://purl.obolibrary.org/obo/fbdv/fbdv-simple.obo
LAST_DEPLOYED_SIMPLE=tmp/$(ONT)-simple-last.obo

$(LAST_DEPLOYED_SIMPLE):
	wget -O $@ $(SIMPLE_PURL)

obo_model=https://raw.githubusercontent.com/FlyBase/flybase-controlled-vocabulary/master/external_tools/perl_modules/releases/OboModel.pm
flybase_script_base=https://raw.githubusercontent.com/FlyBase/drosophila-anatomy-developmental-ontology/master/tools/release_and_checking_scripts/releases/
onto_metrics_calc=$(flybase_script_base)onto_metrics_calc.pl
chado_load_checks=$(flybase_script_base)chado_load_checks.pl
obo_track_new=$(flybase_script_base)obo_track_new.pl
auto_def_sub=$(flybase_script_base)auto_def_sub.pl

export PERL5LIB := ${realpath ../scripts}
install_flybase_scripts:
	wget -O ../scripts/OboModel.pm $(obo_model)
	wget -O ../scripts/onto_metrics_calc.pl $(onto_metrics_calc) && chmod +x ../scripts/onto_metrics_calc.pl
	wget -O ../scripts/chado_load_checks.pl $(chado_load_checks) && chmod +x ../scripts/chado_load_checks.pl
	wget -O ../scripts/obo_track_new.pl $(obo_track_new) && chmod +x ../scripts/obo_track_new.pl
	wget -O ../scripts/auto_def_sub.pl $(auto_def_sub) && chmod +x ../scripts/auto_def_sub.pl
	echo "Warning: Chado load checks currently exclude ISBN wellformedness checks!"

reports/obo_track_new_simple.txt: $(LAST_DEPLOYED_SIMPLE) install_flybase_scripts $(ONT)-simple.obo
	echo "Comparing with: "$(SIMPLE_PURL) && ../scripts/obo_track_new.pl $(LAST_DEPLOYED_SIMPLE) $(ONT)-simple.obo > $@

reports/robot_simple_diff.txt: $(LAST_DEPLOYED_SIMPLE) $(ONT)-simple.obo
	$(ROBOT) diff --left $(ONT)-simple.obo --right $(LAST_DEPLOYED_SIMPLE) --labels true --output $@

reports/onto_metrics_calc.txt: $(ONT)-simple.obo install_flybase_scripts
	../scripts/onto_metrics_calc.pl 'FlyBase_development_CV' $(ONT)-simple.obo > $@

reports/chado_load_check_simple.txt: install_flybase_scripts fly_development.obo
	../scripts/chado_load_checks.pl fly_development.obo > $@

reports/obo_qc_%.txt:
	$(ROBOT) report -i $* --profile qc-profile.txt --fail-on ERROR --print 5 -o $@

######################################################
### Overwriting some default artefacts ###
######################################################
# remove excess defs, labels and comments from obo files

# Simple is overwritten to strip out duplicate names and definitions.
$(ONT)-simple.obo: $(ONT)-simple.owl
	$(ROBOT) convert --input $< --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
	cat $@.tmp.obo | grep -v ^owl-axioms | grep -v 'namespace[:][ ]external' > $@.tmp &&\
	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/comment[:].*\ncomment[:]/comment:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
	rm -f $@.tmp.obo $@.tmp

# We want the OBO release to be based on the simple release. It needs to be annotated however in the way map releases (fbdv.owl) are annotated.
$(ONT).obo: $(ONT)-simple.owl
	$(ROBOT)  annotate --input $< --ontology-iri $(URIBASE)/$@ --version-iri $(ONTBASE)/releases/$(TODAY) \
	convert --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
	cat $@.tmp.obo | grep -v ^owl-axioms | grep -v 'namespace[:][ ]external' > $@.tmp &&\
	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/comment[:].*\ncomment[:]/comment:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
	rm -f $@.tmp.obo $@.tmp

$(ONT)-base.obo: $(ONT)-base.owl
	$(ROBOT) convert --input $< --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
	cat $@.tmp.obo | grep -v ^owl-axioms > $@.tmp &&\
	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/comment[:].*\ncomment[:]/comment:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
	rm -f $@.tmp.obo $@.tmp

$(ONT)-non-classified.obo: $(ONT)-non-classified.owl
	$(ROBOT) convert --input $< --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
	cat $@.tmp.obo | grep -v ^owl-axioms > $@.tmp &&\
	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/comment[:].*\ncomment[:]/comment:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
	rm -f $@.tmp.obo $@.tmp

$(ONT)-full.obo: $(ONT)-full.owl
	$(ROBOT) convert --input $< --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
	cat $@.tmp.obo | grep -v ^owl-axioms > $@.tmp &&\
	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/comment[:].*\ncomment[:]/comment:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
	rm -f $@.tmp.obo $@.tmp


#####################################################################################
### Regenerate placeholder definitions         (Pre-release) pipelines            ###
#####################################################################################
# FBdv does not currently use DOT or SUB definitions:
# "." (DOT-) definitions are those for which the formal definition is translated into a human readable definitions.
# "$sub_" (SUB-) definitions are those that have special placeholder string to substitute in definitions from external ontologies
# support for this was removed from fbdv.Makefile - copy code and sparql from FBcv if needed

#####################################################################################
### Generate the flybase version of fbdv                                          ###
#####################################################################################

tmp/fbdv-obj.obo: fbdv-simple.obo
	$(ROBOT) remove -i fbdv-simple.obo --select object-properties --trim true -o $@.tmp.obo && grep -v ^owl-axioms $@.tmp.obo > $@ && rm $@.tmp.obo

fly_development.obo: fbdv-simple.obo tmp/fbdv-obj.obo rem_flybase.txt
	cp fbdv-simple.obo tmp/fbdv-simple-stripped.obo
	$(ROBOT) remove -vv -i tmp/fbdv-simple-stripped.obo --select "owl:deprecated='true'^^xsd:boolean" --trim true \
		merge --collapse-import-closure false --input tmp/fbdv-obj.obo \
		remove --term-file rem_flybase.txt --trim false \
		query --update ../sparql/force-obo.ru \
		convert -f obo --check false -o $@.tmp.obo
	cat $@.tmp.obo | sed '/./{H;$!d;} ; x ; s/\(\[Typedef\]\nid:[ ]\)\([[:lower:][:punct:]]*\n\)\(name:[ ]\)\([[:lower:][:punct:] ]*\n\)/\1\2\3\2/' | grep -v property_value: | grep -v ^owl-axioms | grep -v FlyBase_miscellaneous_CV | sed s'/^default-namespace: FlyBase_development_CV/default-namespace: FlyBase development CV/' | grep -v ^expand_expression_to | sed '/^date[:]/c\date: $(OBODATE)' | sed '/^data-version[:]/c\data-version: $(DATE)' > $@
	rm $@.tmp.obo
	$(ROBOT) convert --input $@ -f obo --output $@
	sed -i 's/^xref[:][ ]OBO_REL[:]\(.*\)/xref_analog: OBO_REL:\1/' $@
	#sed -i '/^inverse_of[:][ ]ends_at_start_of[ ]\![ ]immediately[ ]precedes/c\inverse_of: ends_at_start_of ! ends_at_start_of' $@
