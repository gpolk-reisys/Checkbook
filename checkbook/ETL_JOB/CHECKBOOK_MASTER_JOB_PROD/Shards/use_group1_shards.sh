#!/bin/sh

# attach shard2
pcp_attach_node 10 web1 9898 pgpool pgpool 1
pcp_attach_node 10 web2 9898 pgpool pgpool 0
pcp_attach_node 10 web3 9898 pgpool pgpool 2

# detach shard1
pcp_detach_node 10 web1 9898 pgpool pgpool 0
pcp_detach_node 10 web2 9898 pgpool pgpool 2
pcp_detach_node 10 web3 9898 pgpool pgpool 1

# detach shard3
pcp_detach_node 10 web1 9898 pgpool pgpool 2
pcp_detach_node 10 web2 9898 pgpool pgpool 1
pcp_detach_node 10 web3 9898 pgpool pgpool 0

wait

echo "PGPool is now using shard2 only"

exit 0