fullnode:
	clear
	cd node/v6;\
		rm -rf data/;\
		../../bin/aptos-node --config vfn.yaml
		# ../../bin/aptos-node --config validator.yaml
