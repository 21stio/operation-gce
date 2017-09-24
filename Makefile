SHELL=/bin/bash
SOURCE=source ./make.sh

cc: create_cluster
create_cluster:
	${SOURCE} && create_cluster

l: list
list:
	${SOURCE} && list

cz: create_zone
create_zone:
	${SOURCE} && create_zone

cr: create_record
create_record:
	${SOURCE} && create_record

rr: remove_record
remove_record:
	${SOURCE} && remove_record

a: apply
apply:
	${SOURCE} && apply

t: test
test:
	${SOURCE} && tests

s: setup
setup:
	${SOURCE} && setup

td: teardown
teardown:
	${SOURCE} && teardown

dfr: delete_forwarding_rule
delete_forwarding_rule:
	${SOURCE} && delete_forwarding_rule