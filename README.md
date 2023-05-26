# AKS Windows Many Pods Bugs

To reproduce the bug -

1. Login to Azure, and select a subscription -
     * `az login`
     * `az account set --subscription <YOUR-SUBSCRIPTION>`

2. Create cluster -
     * `terraform init`
     * `terraform apply -var cluster_name="aks-many-pods-bug"`

   This will crete an AKS cluster named "aks-many-pods-bug" in resource group "aks-many-pods-bug-rg",
   and create a kubeconfig file for it.

3. Confirm it is up -
     * `kubectl --kubeconfig=kubeconfig get nodes`

4. Create a single pod on the Windows node, and wait for it to start (this is
   done to make sure the image is pulled to the node, as there is a different
   bug related to pulling the same image concurrently) -
     * `kubectl --kubeconfig=kubeconfig apply -f wait-forever-deployment.yml`
     * `kubectl --kubeconfig=kubeconfig rollout status -w deployment/wait-forever`

5. Scale the amount of replicas up to 200 -
     * `kubectl --kubeconfig=kubeconfig scale --replicas=200 deployment/wait-forever`

6. Wait for some time (usually, around 15 minutes).

7. Observe that deployment is **successful**, but various warnings are still reported.
     * `kubectl --kubeconfig=kubeconfig get deployment`
     * `kubectl --kubeconfig=kubeconfig get events --sort-by='.lastTimestamp'`

   These are warnings/statuses seen -
     * "Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup
       network for sandbox "7d04a736b37345a9c0147625f5f156f340277877a62b8d86f68d6745a9f41895":
       plugin type="azure-vnet" failed (add): Failed to initialize key-value store of network
       plugin: timed out locking store"
     * "Filed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network
       for sandbox "1c27f3d6924dc80298273385250f5f19598520eb0a52cdf4898094f6bbf85691": plugin
       type="azure-vnet" failed (add): Failed to create endpoint: Failed to create endpoint:
       1c27f3d6-eth0 due to error: hcnCreateEndpoint failed in Win32: An address provided is
       invalid or reserved. (0x803b002f) {"Success":false,"Error":"An address provided is
       invalid or reserved. ","ErrorCode":2151350319}"
     * "Failed to create pod sandbox: rpc error: code = Unknown desc = failed to reserve sandbox
       name "wait-forever-5ff557cddd-bl77x_default_d43e2581-c44d-4007-8b53-969768e82448_1": name
       "wait-forever-5ff557cddd-bl77x_default_d43e2581-c44d-4007-8b53-969768e82448_1" is
       reserved for "b36896640d18b974102bd59edb617a32c53aaafeb41cd535097caa7876a1ef20""
     * "Pod sandbox changed, it will be killed and re-created."

8. Delete the deployment -
     * `kubectl --kubeconfig=kubeconfig delete deployment wait-forever`

9. At this point, the node should be in healthy state. If it gets to a non-recoverable state,
   scale the node pool down to 0 and back to 1 to get a fresh node.
     * `az aks nodepool scale --resource-group aks-many-pods-bug-rg --cluster-name aks-many-pods-bug --nodepool-name win1 --node-count 0`
     * `az aks nodepool scale --resource-group aks-many-pods-bug-rg --cluster-name aks-many-pods-bug --nodepool-name win1 --node-count 1`

10. Eventually, destroy the cluster -
      * `terraform destroy`
