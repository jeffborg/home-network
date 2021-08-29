#!/bin/bash
# based upon https://community.ui.com/questions/Dynamically-updating-an-address-group-with-a-script/fc25b83e-7b9e-4878-8b92-166185c943e2#answer/bec2da2d-b63a-4ba3-bb3d-0a6d5de4d7ac

vop=/opt/vyatta/bin/vyatta-op-cmd-wrapper
vcfg=/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper


# Hostnames to look up
hostnames=(example-site.com example-othersite.com)

# Static IPs to add to BYPASS_LOAD_BALANCER
#static_ips=()


# get current list of addresses in the BYPASS_LOAD_BALANCER address group
bypass_load_balancer=($($vop show firewall group BYPASS_LOAD_BALANCER | grep -A5 Members |grep -v Members | awk '{ print $1 }' ))

# resolve trusted hostnames
resolved_ips=($(getent ahosts ${hostnames[@]} | grep STREAM | grep -v : | awk '{ print $1 }' | LC_ALL=C sort | uniq))
# resolved_ips=($(getent hosts ${hostnames[@]} | awk '{ print $1 }'))

# add static IPs to resolved IPs
#resolved_ips+=(${static_ips[@]})

# match BYPASS_LOAD_BALANCER IPs against resolved IPs
matched_ips=($(comm -12 <(printf '%s\n' "${bypass_load_balancer[@]}" | LC_ALL=C sort) <(printf '%s\n' "${resolved_ips[@]}" | LC_ALL=C sort)))


# Update address group if IPs changed
if [ ${#matched_ips[@]} -eq ${#bypass_load_balancer[@]} ] && [ ${#matched_ips[@]} -eq ${#resolved_ips[@]} ]; then
  # IPs did not change. Do nothing
  :
else
  #if addresses have changed, remove address-group "BYPASS_LOAD_BALANCER" and recreate it with the new addresses
  logger "Trusted WAN IPs changed. Updating BYPASS_LOAD_BALANCER address group."
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  $vcfg begin
  $vcfg delete firewall group address-group BYPASS_LOAD_BALANCER
  $vcfg set firewall group address-group BYPASS_LOAD_BALANCER description "Bypass load balancer targets"
  for ip in ${resolved_ips[@]}; do
    $vcfg set firewall group address-group BYPASS_LOAD_BALANCER address "$ip"
  done
  $vcfg commit
  $vcfg save
  $vcfg end
fi
