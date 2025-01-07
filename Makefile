v6_vfn:
	clear
	cd node/v6;\
		rm -rf data/;\
		../../bin/aptos-node --config vfn.yaml
		# ../../bin/aptos-node --config validator.yaml

v3_pfn:
	clear
	cd node/v3;\
		rm -rf data/;\
		../../bin/aptos-node --config pfn.yaml
		# ../../bin/aptos-node --config validator.yaml
