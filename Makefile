SHELL=/bin/bash
SOURCE=source ./make.sh

c: create
create:
	${SOURCE} && create

l: list
list:
	${SOURCE} && list

cz: create_zone
create_zone:
	${SOURCE} && create_zone

cr: create_record
create_record:
	${SOURCE} && create_record

a: apply
apply:
	${SOURCE} && apply

t: test
test:
	${SOURCE} && tests