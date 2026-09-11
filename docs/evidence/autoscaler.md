# Cluster Autoscaler Evidence

The temporary pressure workload used six `registry.k8s.io/pause:3.10` replicas with requests and limits of `1500m` CPU and `1Gi` memory per pod.

- Baseline node count: 3
- Immediate workload state: 4 Pending, 2 Ready
- Peak node count: 6
- Peak workload state: 2 Pending, 4 Ready
- Temporary namespace: `capstone-autoscaler-test`
- Cleanup: namespace deleted and confirmed absent
- Scale-in: node group returned to the configured minimum of 3 nodes
- Node group limits: min 3, desired 3 after cleanup, max 6

The test also identified and fixed the Cluster Autoscaler RBAC and IRSA permissions required for leader election, Kubernetes 1.36 resource watches, node taint updates, status reporting, and `eks:DescribeNodegroup`.
