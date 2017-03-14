all: documentation.m.html

documentation.m.html: documentation.m
	perl kpp.pl $<

clean:
	rm -f documentation.m.html

.PHONY: clean all
