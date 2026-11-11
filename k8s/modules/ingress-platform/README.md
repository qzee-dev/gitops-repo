# Legacy ingress platform module

The dev, staging, and production Terraform roots now select from dedicated
controller modules in `k8s/modules/` using static module source paths and
conditional `count`. They do not call this legacy module directly.

The `charts/routes` and `charts/frontend` subdirectories remain shared
implementation assets used by the dedicated controller modules. Do not
instantiate this legacy module alongside those modules: that can create
duplicate Helm releases, routes, or shared add-ons.

The AWS Load Balancer Controller is owned by the environment platform layer,
not by the `aws-alb-controller` route module. The route module creates ALB
Ingress resources and reuses the already-installed AWS controller.
