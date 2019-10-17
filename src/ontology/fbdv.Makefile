## Customize Makefile settings for fbdv
## 
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile

DATE   ?= $(shell date +%Y-%m-%d)

######################################################
### Code for generating additional FlyBase reports ###
######################################################

# Illegal division by 0 problem: reports/onto_metrics_calc.txt 
REPORT_FILES := $(REPORT_FILES) reports/obo_track_new_simple.txt  reports/robot_simple_diff.txt

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

install_flybase_scripts:
	wget -O ../scripts/OboModel.pm $(obo_model)
	cp ../scripts/OboModel.pm /usr/local/lib/perl5/site_perl
	wget -O ../scripts/onto_metrics_calc.pl $(onto_metrics_calc) && chmod +x ../scripts/onto_metrics_calc.pl
	wget -O ../scripts/chado_load_checks.pl $(chado_load_checks) && chmod +x ../scripts/chado_load_checks.pl
	wget -O ../scripts/obo_track_new.pl $(obo_track_new) && chmod +x ../scripts/obo_track_new.pl
	wget -O ../scripts/auto_def_sub.pl $(auto_def_sub) && chmod +x ../scripts/auto_def_sub.pl
	echo "Warning: Chado load checks currently exclude ISBN wellformedness checks!"

reports/obo_track_new_simple.txt: $(LAST_DEPLOYED_SIMPLE) install_flybase_scripts $(ONT)-simple.obo
	echo "Comparing with: "$(SIMPLE_PURL) && ../scripts/obo_track_new.pl $(LAST_DEPLOYED_SIMPLE) $(ONT)-simple.obo > $@

reports/robot_simple_diff.txt: $(LAST_DEPLOYED_SIMPLE) $(ONT)-simple.obo
	$(ROBOT) diff --left $(ONT)-simple.obo --right $(LAST_DEPLOYED_SIMPLE) --output $@

reports/onto_metrics_calc.txt: $(ONT)-simple.obo install_flybase_scripts
	../scripts/onto_metrics_calc.pl 'phenotypic_class' $(ONT)-simple.obo > $@
	
reports/chado_load_check_simple.txt: install_flybase_scripts fly_development.obo 
	../scripts/chado_load_checks.pl fly_development.obo > $@

all_reports: all_reports_onestep $(REPORT_FILES)

prepare_release: $(ASSETS) $(PATTERN_RELEASE_FILES)
	rsync -R $(ASSETS) $(RELEASEDIR) &&\
	echo "Release files are now in $(RELEASEDIR) - now you should commit, push and make a release on github"


######################################################
### Overwriting some default aretfacts ###
######################################################

# Simple is overwritten to strip out duplicate names and definitions.
$(ONT)-simple.obo: $(ONT)-simple.owl
	$(ROBOT) convert --input $< --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
	grep -v ^owl-axioms $@.tmp.obo > $@.tmp &&\
	sed -i '/subset[:] ro[-]eco/d' $@.tmp &&\
	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/comment[:].*\ncomment[:]/comment:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
	sed -i '/namespace[:][ ]external/d' $@
	rm -f $@.tmp.obo $@.tmp

# We want the OBO release to be based on the simple release. It needs to be annotated however in the way map releases (fbdv.owl) are annotated.
$(ONT).obo: $(ONT)-simple.owl
	$(ROBOT)  annotate --input $< --ontology-iri $(URIBASE)/$@ --version-iri $(ONTBASE)/releases/$(TODAY) \
	convert --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
	grep -v ^owl-axioms $@.tmp.obo > $@.tmp &&\
	sed -i '/subset[:] ro[-]eco/d' $@.tmp &&\
	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/comment[:].*\ncomment[:]/comment:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
	sed -i '/namespace[:][ ]external/d' $@
	rm -f $@.tmp.obo $@.tmp

#ont.obo:
#	$(ROBOT) annotate --input $(ONT)-simple.owl --ontology-iri $(URIBASE)/$@ --version-iri $(ONTBASE)/releases/$(TODAY) \
#	convert --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
#	grep -v ^owl-axioms $@.tmp.obo > $@.tmp &&\
#	sed -i '/subset[:] ro[-]eco/d' $@.tmp &&\
#	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
#	rm -f $@.tmp.obo $@.tmp

#non_native_classes.txt: $(SRC)
#	$(ROBOT) query --use-graphs true -f csv -i $< --query ../sparql/non-native-classes.sparql $@.tmp &&\
#	cat $@.tmp | sort | uniq >  $@
#	rm -f $@.tmp


#####################################################################################
### Regenerate placeholder definitions         (Pre-release) pipelines            ###
#####################################################################################
# There are two types of definitions that fbdv uses: "." (DOT-) definitions are those for which the formal 
# definition is translated into a human readable definitions. "$sub_" (SUB-) definitions are those that have 
# special placeholder string to substitute in definitions from external ontologies, mostly GO

LABEL_MAP = auto_generated_definitions_label_map.txt

tmp/auto_generated_definitions_seed_dot.txt: $(SRC)
	$(ROBOT) query --use-graphs false -f csv -i $(SRC) --query ../sparql/dot-definitions.sparql $@.tmp &&\
	cat $@.tmp | sort | uniq >  $@
	rm -f $@.tmp
	
tmp/auto_generated_definitions_seed_sub.txt: $(SRC)
	$(ROBOT) query --use-graphs false -f csv -i $(SRC) --query ../sparql/classes-with-placeholder-definitions.sparql $@.tmp &&\
	cat $@.tmp | sort | uniq >  $@
	rm -f $@.tmp

tmp/merged-source-pre.owl: $(SRC) mirror/go.owl
	$(ROBOT) merge -i $(SRC) -i mirror/go.owl --output $@

tmp/auto_generated_definitions_dot.owl: tmp/merged-source-pre.owl tmp/auto_generated_definitions_seed_dot.txt
	java -jar ../scripts/eq-writer.jar $< tmp/auto_generated_definitions_seed_dot.txt flybase $@ $(LABEL_MAP) add_dot_refs

tmp/auto_generated_definitions_sub.owl: tmp/merged-source-pre.owl tmp/auto_generated_definitions_seed_sub.txt
	java -jar ../scripts/eq-writer.jar $< tmp/auto_generated_definitions_seed_sub.txt sub_external $@ $(LABEL_MAP) source_xref

tmp/replaced_defs.txt:
	cat tmp/auto_generated_definitions_seed_sub.txt tmp/auto_generated_definitions_seed_dot.txt | sort | uniq > $@

tmp/remove_dot_defs.txt: tmp/auto_generated_definitions_seed_dot.txt
	cp $< $@
	echo "http://purl.obolibrary.org/obo/IAO_0000115" >> $@
	echo "http://www.geneontology.org/formats/oboInOwl#hasDbXref" >> $@

pre_release: $(ONT)-edit.obo tmp/auto_generated_definitions_dot.owl tmp/auto_generated_definitions_sub.owl tmp/remove_dot_defs.txt
	cp $(ONT)-edit.obo tmp/$(ONT)-edit-release.obo
	$(ROBOT) query -i tmp/$(ONT)-edit-release.obo --update ../sparql/remove-dot-definitions.ru convert -f obo --check false -o tmp/$(ONT)-edit-release.obo
	sed -i '/sub_/d' tmp/$(ONT)-edit-release.obo
	$(ROBOT) merge -i tmp/$(ONT)-edit-release.obo -i tmp/auto_generated_definitions_dot.owl -i tmp/auto_generated_definitions_sub.owl --collapse-import-closure false -o $(ONT)-edit-release.ofn && mv $(ONT)-edit-release.ofn $(ONT)-edit-release.owl
	echo "Preprocessing done. Make sure that NO CHANGES TO THE EDIT FILE ARE COMMITTED!"

#####################################################################################
### Generate the flybase anatomy version of fbdv                                  ###
#####################################################################################

tmp/fbdv-obj.obo:
	$(ROBOT) remove -i fbdv-simple.obo --select object-properties --trim true -o $@.tmp.obo && grep -v ^owl-axioms $@.tmp.obo > $@ && rm $@.tmp.obo

fly_development.obo: tmp/fbdv-obj.obo rem_flybase.txt
	cp fbdv-simple.obo tmp/fbdv-simple-stripped.obo
	#cat fbdv-simple.obo | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > tmp/fbdv-simple-stripped.obo &&\
	$(ROBOT) remove -vv -i tmp/fbdv-simple-stripped.obo --select "owl:deprecated='true'^^xsd:boolean" --trim true \
		merge --collapse-import-closure false --input tmp/fbdv-obj.obo \
		remove --term-file rem_flybase.txt --trim false \
		query --update ../sparql/force-obo.ru \
		convert -f obo --check false -o $@.tmp.obo
	cat $@.tmp.obo | sed 's/^xref: OBO_REL:part_of/xref_analog: OBO_REL:part_of/' | sed 's/^xref: OBO_REL:has_part/xref_analog: OBO_REL:has_part/' | sed 's/^xref: OBO_REL:preceded_by/xref_analog: OBO_REL:preceded_by/' | grep -v property_value: | grep -v ^owl-axioms | sed s'/^default-namespace: FlyBase_development_CV/default-namespace: FlyBase development CV/' | grep -v ^expand_expression_to > $@  
	rm $@.tmp.obo
	sed -i '/^date[:]/c\date: $(OBODATE)' $@
	sed -i '/^data-version[:]/c\data-version: $(DATE)' $@
	sed -i '/FlyBase_miscellaneous_CV/d' $@
	# temporary retention of part_of and removes and puts back typedefs from simple without substage_of
	sed -i 's/substage_of/part_of/' $@
	sed -i '/\[Typedef\]/,$$d' $@
	echo "[Typedef]" >> $@
	echo "id: ends_at_start_of" >> $@
	echo "name: ends_at_start_of" >> $@
	echo "comment: X immediately_precedes_Y iff: end(X) simultaneous_with start(Y)" >> $@
	echo "xref: RO:0002090" >> $@
	echo "" >> $@
	echo "[Typedef]" >> $@
	echo "id: happens_during" >> $@
	echo "name: happens_during" >> $@
	echo "comment: X happens_during Y iff: (start(Y) before_or_simultaneous_with start(X)) AND (end(X) before_or_simultaneous_with end(Y))" >> $@
	echo "xref: RO:0002092" >> $@
	echo "is_transitive: true" >> $@
	echo "is_a: occurent_part_of ! occurent_part_of" >> $@
	echo "" >> $@
	echo "[Typedef]" >> $@
	echo "id: has_part" >> $@
	echo "name: has_part" >> $@
	echo "namespace: relationship" >> $@
	echo "def: \"a core relation that holds between a whole and its part\" []" >> $@
	echo "xref: BFO:0000051" >> $@
	echo "xref_analog: OBO_REL:has_part" >> $@
	echo "is_transitive: true" >> $@
	echo "is_a: overlaps ! overlaps" >> $@
	echo "" >> $@
	echo "[Typedef]" >> $@
	echo "id: immediately_preceded_by" >> $@
	echo "name: immediately_preceded_by" >> $@
	echo "comment: X immediately_preceded_by Y iff: end(X) simultaneous_with start(Y)" >> $@
	echo "xref: RO:0002087" >> $@
	echo "is_a: preceded_by ! preceded_by" >> $@
	echo "inverse_of: ends_at_start_of ! ends_at_start_of" >> $@
	echo "" >> $@
	echo "[Typedef]" >> $@
	echo "id: occurent_part_of" >> $@
	echo "name: occurent_part_of" >> $@
	echo "def: \"A part of relation that applies only between occurents.\" []" >> $@
	echo "xref: RO:0002012" >> $@
	echo "is_a: overlaps ! overlaps" >> $@
	echo "" >> $@
	echo "[Typedef]" >> $@
	echo "id: overlaps" >> $@
	echo "name: overlaps" >> $@
	echo "def: \"x overlaps y if and only if there exists some z such that x has part z and z part of y\" []" >> $@
	echo "xref: RO:0002131" >> $@
	echo "holds_over_chain: has_part overlaps" >> $@
	echo "" >> $@
	echo "[Typedef]" >> $@
	echo "id: part_of" >> $@
	echo "name: part_of" >> $@
	echo "namespace: relationship" >> $@
	echo "xref: BFO:0000050" >> $@
	echo "xref_analog: OBO_REL:part_of" >> $@
	echo "is_transitive: true" >> $@
	echo "" >> $@
	echo "[Typedef]" >> $@
	echo "id: preceded_by" >> $@
	echo "name: preceded_by" >> $@
	echo "namespace: relationship" >> $@
	echo "def: \"x is preceded by y if and only if the time point at which y ends is before or equivalent to the time point at which x starts. Formally: x preceded by y iff ω(y) <= α(x), where α is a function that maps a process to a start point, and ω is a function that maps a process to an end point.\" []" >> $@
	echo "xref: BFO:0000062" >> $@
	echo "xref_analog: OBO_REL:preceded_by" >> $@
	echo "is_transitive: true" >> $@
	echo "holds_over_chain: happens_during preceded_by" >> $@
	echo "is_transitive: true" >> $@
	echo "" >> $@

post_release: fly_development.obo reports/chado_load_check_simple.txt
	cp fly_development.obo ../..
	
########################
##    TRAVIS       #####
########################

obo_qc_%:
	$(ROBOT) report -i $* --profile qc-profile.txt --fail-on ERROR --print 5 -o $@.txt

obo_qc: obo_qc_$(ONT).obo obo_qc_$(ONT).owl

flybase_qc: odkversion obo_qc
	$(ROBOT) reason --input $(ONT)-full.owl --reasoner ELK  --equivalent-classes-allowed asserted-only --output test.owl && rm test.owl && echo "Success"

