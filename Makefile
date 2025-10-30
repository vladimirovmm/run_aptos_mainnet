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

run__cluster:
	process-compose up -p 8079

NODE_V1 = ./node/v1
LUMIO_REP = ../lumio-node
make v1_rebuild_and_restart:
# 	rm -rf $(NODE_V1)/data
	cd $(LUMIO_REP); \
		cargo build -p lumio-node --features indexer;
	cp $(LUMIO_REP)/target/debug/lumio-node $(NODE_V1);
	cd $(NODE_V1);\
		RUST_LOG=ERROR ./lumio-node --config configs/validator.yaml