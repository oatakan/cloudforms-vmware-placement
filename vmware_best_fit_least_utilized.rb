###################################
#
# EVM Automate Method: best_fit_cluster_by_tags
#
# Notes: This method is used to find all hosts, datastores that match the required tag
#
###################################
begin
  @method = 'best_fit_cluster_by_tags'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true

  #
  # Get variables
  #
  prov = $evm.root["miq_provision"]
  vm = prov.vm_template
  raise "VM not specified" if vm.nil?
  ems  = vm.ext_management_system
  raise "EMS not found for VM [#{vm.name}" if ems.nil?
  tags = prov.get_tags
 

tags = vm.tags

$evm.log("info", "Template Tags - #{vm.tags}")

tags.each  do  |t|
 s = t.split("/") 
  if s[0] == 'prov_scope'
      @prov_tag = s[1]    
  end
end

$evm.log("info", "Template is tagged with - #{@prov_tag}")


myclusters = $evm.vmdb("ems_cluster").all
myclusters.each do | cluster | 
  cluster_tags = cluster.tags
     cluster_tags.each  do  |t|
     s = t.split("/") 
     if s[0] == 'prov_scope'
        @clus_tag = s[1] 
        if @clus_tag == @prov_tag 
          @clus_hosts = cluster.hosts
        end
     end
  end
end

$evm.log("info", "Cluster(s) is/are tagged with - #{@clus_tag}")
@clus_hosts.each do | host |
    $evm.log("info", "Host in cluster -- #{host.name}")
end


  # Log all provisioning options and space required
  $evm.log("info", "options: #{prov.options.inspect}") if @debug
  $evm.log("info", "Inline Method: <#{@method}> -- vm=[#{vm.name}], space required=[#{vm.provisioned_storage}]")

  # STORAGE LIMITATIONS
  STORAGE_MAX_VMS      = 0
  storage_max_vms      = $evm.object['storage_max_vms']
  storage_max_vms      = storage_max_vms.strip.to_i if storage_max_vms.kind_of?(String) && !storage_max_vms.strip.empty?
  storage_max_vms      = STORAGE_MAX_VMS unless storage_max_vms.kind_of?(Numeric)

  STORAGE_MAX_PCT_USED = 100
  storage_max_pct_used = $evm.object['storage_max_pct_used']
  storage_max_pct_used = storage_max_pct_used.strip.to_i if storage_max_pct_used.kind_of?(String) && !storage_max_pct_used.strip.empty?
  storage_max_pct_used = STORAGE_MAX_PCT_USED unless storage_max_pct_used.kind_of?(Numeric)

  host = storage = nil
  min_registered_vms = nil
  @clus_hosts.each { |h|
#    next unless h.power_state == "on"
    $evm.log("info", "Looking at host -- #{h.name}")
    nvms = h.vms.length

  
    # Filter out storages that do not have enough free space for the Vm
    storages = h.storages.find_all { |s|
      if s.free_space > vm.provisioned_storage
        $evm.log("info", "Storage Space -- #{s.free_space} is > than #{vm.provisioned_storage}")    
        true
      else
        $evm.log("info", "Skipping Datastore: [#{s.name}], not enough free space for VM. Available: [#{s.free_space}], Needs: [#{vm.provisioned_storage}]")
        false
      end
    }
    # Filter out storages number of VMs is greater than the max number of VMs
    storages = storages.find_all { |s|
      if (storage_max_vms == 0) || (s.vms.size < storage_max_vms)
        true
      else
        $evm.log("info", "Skipping Datastore: [#{s.name}], max number of VMs exceeded")
        false
      end
    }
    # Filter out storages where percent used is greater than the max.
    storages = storages.find_all { |s|
      if (storage_max_pct_used == 100) || (s.v_used_space_percent_of_total < storage_max_pct_used)
        true
      else
        $evm.log("info", "Skipping Datastore: [#{s.name}], percent of used space is exceeded")
        false
      end
    }
    # if minimum registered vms is nil or number of vms on a host is greater than nil
    if min_registered_vms.nil? || nvms < min_registered_vms
      s = storages.sort { |a,b| a.free_space <=> b.free_space }.last
      unless s.nil?
        host    = h
        storage = s
        min_registered_vms = nvms
      end
    end
  }

  # Set host and storage
  obj = $evm.object
  obj["host"]    = host    unless host.nil?
  obj["storage"] = storage unless storage.nil?

  $evm.log("info", "Inline Method: <#{@method}> -- vm=[#{vm.name}] host=[#{host}] storage=[#{storage}]")

  #
  # Exit method
  #
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
