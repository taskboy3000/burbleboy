TEST_FILES = t/*.t

test : $(TEST_FILES)
	perl t/.runtests.pl $(TEST_FILES)

indent :
	find lib/ bin/ t/ \( -name '*.pm' -o -name '*.pl' -o -name '*.t' \) | xargs perltidy -b

critic :
	perlcritic --stern lib/

coverage :
	cover -test

clean :
	find . -name '*.bak' -delete
	rm -rf cover_db
	rm -f 202*y*.html
