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

6. Wait for some time (usually, around 10 minutes).

7. Observe that deployment isn't successful, and some pods are in various error states.
     * `kubectl --kubeconfig=kubeconfig get pods | grep ContainerCreating`
     * `kubectl --kubeconfig=kubeconfig get deployment`
     * `kubectl --kubeconfig=kubeconfig get events --sort-by='.lastTimestamp'`

   These are warnings seen -
     * "Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup 
       network for sandbox "344d0dd404b9445599f4805e2ed88437a2514d755943e3e71970d3adf719a5b6": 
       plugin type="azure-vnet" failed (add): Failed to initialize key-value store of network 
       plugin: timed out locking store"
     * "Failed to create pod sandbox: rpc error: code = Unknown desc = failed to create
       containerd task: failed to create shim task: hcs::CreateComputeSystem 
       6968702e67e4dfe1915cd8d6b1920fb5cf6fff6045b595af710d370c8e5818f3: The requested 
       operation for attach namespace failed.: unknown"
     * "Failed to create pod sandbox: rpc error: code = DeadlineExceeded desc = context
       deadline exceeded"
     * "Error: failed to reserve container name
       "wait-forever_wait-forever-5ff557cddd-z8j28_default_dbe8d63c-d20c-4cc0-b817-32762c21c206_0": name
       "wait-forever_wait-forever-5ff557cddd-z8j28_default_dbe8d63c-d20c-4cc0-b817-32762c21c206_0" is
       reserved for "59ab29510e8158b2d5a5be673ec28f768fe0fec189e7ac590e337bb0b2bea473"
     * "Error: context deadline exceeded"
     * "Failed to create pod sandbox: rpc error: code = Unknown desc = failed to reserve sandbox
       name "wait-forever-5ff557cddd-wj5hl_default_76bed184-d876-4eb9-891e-5f2a4cc9f82c_1": name
       "wait-forever-5ff557cddd-wj5hl_default_76bed184-d876-4eb9-891e-5f2a4cc9f82c_1" is reserved 
       for "2479d3c20c5baa9cb9e8d39661c7b5184b51bffeb9b4702ab3bba13befbdd81a""

8. Delete the deployment -
     * `kubectl --kubeconfig=kubeconfig delete deployment wait-forever`

9. At this point, the node might be in a non-recoverable state, with many pods stuck in
   "Terminating". Scale the nodepool down to 0 and back to 1 to get a fresh node.
     * `az aks nodepool scale --resource-group aks-many-pods-bug-rg --cluster-name aks-many-pods-bug --nodepool-name win1 --node-count 0`
     * `az aks nodepool scale --resource-group aks-many-pods-bug-rg --cluster-name aks-many-pods-bug --nodepool-name win1 --node-count 1`

10. Eventually, destroy the cluster -
      * `terraform destroy`
