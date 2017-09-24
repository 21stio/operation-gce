#!/bin/bash

set -e

function validate_requirements {
	binary_is_present gcloud
	binary_is_present kubectl
	binary_is_present jinja2
	binary_is_present htpasswd
}

function binary_is_present {
	binary=$1

	which ${binary} > /dev/null || (echo "${binary} is not present" && exit 1)
}

function validate_environment {
	if [ -z ${PROJECT+x} ]; then echo "PROJECT is not set"; exit 1; fi
	if [ -z ${CLUSTER_HOST_SUB+x} ]; then echo "CLUSTER_HOST_SUB is not set"; exit 1; fi
    if [ -z ${CLUSTER_HOST_NAME+x} ]; then echo "CLUSTER_HOST_NAME is not set"; exit 1; fi
    if [ -z ${CLUSTER_HOST_TLD+x} ]; then echo "CLUSTER_HOST_TLD is not set"; exit 1; fi
    if [ -z ${HTPASSWD_USER+x} ]; then echo "HTPASSWD_USER is not set"; exit 1; fi
    if [ -z ${HTPASSWD_PASSWORD+x} ]; then echo "HTPASSWD_PASSWORD is not set"; exit 1; fi
}

validate_requirements
validate_environment

function create_cluster {
    gcloud --project=${PROJECT} container clusters create \
		--cluster-version=1.7.5 \
		--disable-addons=HttpLoadBalancing \
		--disk-size=50 \
		--enable-cloud-endpoints \
		--enable-cloud-logging \
		--enable-cloud-monitoring \
		--max-nodes-per-pool=100 \
		--machine-type=n1-standard-1 \
		--num-nodes=1 \
		$(get_cluster_name)
}

function delete_cluster {
    gcloud --project=${PROJECT} container clusters delete $(get_cluster_name)
}

function get_cluster_name() {
	echo ${CLUSTER_HOST_SUB}-${CLUSTER_HOST_NAME}-${CLUSTER_HOST_TLD}
}

function list {
	echo "$(
		printf "\n -- dns\n"
		gcloud dns record-sets list --zone $(get_dns_zone)
    )" &

    echo "$(
		printf "\n -- forwarding-rules\n"
		gcloud compute forwarding-rules list
	)" &

	echo "$(
		printf "\n -- target-pools\n"
		gcloud compute target-pools list
	)" &

	echo "$(
		printf "\n -- clusters\n"
		gcloud container clusters list
	)" &

	wait
}

function create_zone {
	gcloud --project=${PROJECT} dns managed-zones create $(get_dns_zone) --dns-name=$(get_dns_name) --description=
}

function get_dns_zone() {
	echo ${CLUSTER_HOST_NAME}-${CLUSTER_HOST_TLD}
}

function get_dns_name() {
	echo ${CLUSTER_HOST_NAME}.${CLUSTER_HOST_TLD}
}

function create_record {
	rm transaction.yaml ||

	gcloud --project=${PROJECT} dns record-sets transaction start --zone=$(get_dns_zone)
	gcloud --project=${PROJECT} dns record-sets transaction add --zone=$(get_dns_zone) --name=$(get_cluster_host). --ttl=60 --type=A $(get_ingress_ip)
	gcloud --project=${PROJECT} dns record-sets transaction add --zone=$(get_dns_zone) --name=\*.$(get_cluster_host). --ttl=60 --type=A $(get_ingress_ip)
	gcloud --project=${PROJECT} dns record-sets transaction execute --zone=$(get_dns_zone)
}

function delete_record {
	rm transaction.yaml ||

	gcloud --project=${PROJECT} dns record-sets transaction start --zone=$(get_dns_zone)
	gcloud --project=${PROJECT} dns record-sets transaction remove --zone=$(get_dns_zone) --name=$(get_cluster_host). --ttl=60 --type=A $(get_ingress_ip)
	gcloud --project=${PROJECT} dns record-sets transaction remove --zone=$(get_dns_zone) --name=\*.$(get_cluster_host). --ttl=60 --type=A $(get_ingress_ip)
	gcloud --project=${PROJECT} dns record-sets transaction execute --zone=$(get_dns_zone)
}

function apply {
	gcloud --project=${PROJECT} container clusters get-credentials $(get_cluster_name)

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
		--filename <(jinja2 k8s/traefik.yaml -D cluster_host=$(get_cluster_host) -D htpasswd=$(generate_htpasswd))

	kubectl apply \
		--namespace default \
		--filename <(jinja2 k8s/echoheaders.yaml -D cluster_host=$(get_cluster_host))

	kubectl apply \
		--namespace kube-system \
		--filename <(jinja2 k8s/dashboard.yaml -D cluster_host=$(get_cluster_host))
}

function get_ingress_ip {
	gcloud --project=${PROJECT} container clusters get-credentials $(get_cluster_name)

	kubectl get service traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
}

function tests {
	python3 ./tests/tests.py ${CLUSTER_URL}
}

function get_cluster_host {
	echo ${CLUSTER_HOST_SUB}.${CLUSTER_HOST_NAME}.${CLUSTER_HOST_TLD}
}

function get_forwarding_rule_name {
	gcloud compute forwarding-rules list --format json | jq -r ".[0].name"
}

function get_forwarding_rule_region {
	gcloud compute forwarding-rules list --format json | jq -r ".[0].region"
}

function get_target_pool_name {
	gcloud compute target-pools list --format json | jq -r ".[0].name"
}

function get_target_pool_region {
	gcloud compute target-pools list --format json | jq -r ".[0].region"
}

function delete_forwarding_rule {
	gcloud compute forwarding-rules delete --region=$(get_forwarding_rule_region) $(get_forwarding_rule_name)
}

function delete_target_pool {
	gcloud compute target-pools delete --region=$(get_target_pool_region) $(get_target_pool_name)
}

function generate_htpasswd {
	htpasswd -b -n ${HTPASSWD_USER} ${HTPASSWD_PASSWORD}
}

function teardown {
	delete_record ||
	delete_forwarding_rule ||
	delete_target_pool ||
	delete_cluster
}

function setup {
	create_cluster ||
	apply ||
	sleep 30
	create_record
}