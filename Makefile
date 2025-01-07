v6_vfn:
	clear
	cd node/v6;\
		rm -rf data/;\
		../../bin/aptos-node --config vfn.yaml
		# ../../bin/aptos-node --config validator.yaml

v7_pfn:
	clear
	cd node/v7;\
		rm -rf data/;\
		../../bin/aptos-node --config pfn.yaml
		# ../../bin/aptos-node --config validator.yaml
