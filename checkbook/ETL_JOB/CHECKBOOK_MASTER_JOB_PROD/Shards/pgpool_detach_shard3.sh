#!/bin/sh

# detach shard3
pcp_detach_node 10 web1 9898 pgpool pgpool 2
pcp_detach_node 10 web2 9898 pgpool pgpool 1
pcp_detach_node 10 web3 9898 pgpool pgpool 0