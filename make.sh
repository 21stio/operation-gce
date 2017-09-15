#!/bin/bash

CLUSTER_NAME=blue
CLUSTER_DOMAIN=sunsparks.xyz
CLUSTER_URL=${CLUSTER_NAME}.${CLUSTER_DOMAIN}

function create {
    gcloud container clusters create \
		--cluster-version=1.7.5 \
		--disable-addons=HttpLoadBalancing \
		--disk-size=50 \
		--enable-cloud-endpoints \
		--enable-cloud-logging \
		--enable-cloud-monitoring \
		--max-nodes-per-pool=100 \
		--machine-type=n1-standard-1 \
		--num-nodes=1 \
		${CLUSTER_NAME}
}

function list {
    gcloud container clusters list
}

function create_zone {
	gcloud dns --project=go-snapper managed-zones create sunsparks-xyz --dns-name=sunsparks.xyz --description=
}

function create_record {
	gcloud dns record-sets import --zone sunsparks-xyz <(printf "kind: dns#resourceRecordSet\nname: ${CLUSTER_NAME}.${CLUSTER_DOMAIN}.\nrrdatas:\n- $(get_ingress_ip)\nttl: 60\ntype: A")
}

function apply {
	kubectl apply \
		--namespace default \
		--filename k8s/rbac.yaml

	kubectl apply \
		--namespace default \
		--filename k8s/limits.yaml

	kubectl apply \
		--namespace kube-system \
		--filename k8s/limits.yaml

	kubectl apply \
		--namespace default \
		--filename k8s/traefik.yaml

	kubectl apply \
		--namespace default \
		--filename k8s/echoheaders.yaml

	kubectl apply \
		--namespace kube-system \
		--filename k8s/dashboard.yaml
}

function get_ingress_ip {
	kubectl get service traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
}

function tests {
	python3 ./tests/tests.py ${CLUSTER_URL}
}