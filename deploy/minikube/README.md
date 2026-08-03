# standup on minikube

A hand-rolled deployment, used to verify the MCP server against a real cluster
rather than a laptop `jac start`.

## Why not `jac start --scale`?

That is the supported path and it is the one you should prefer on Linux. It
does **not** work from a macOS host against a Linux cluster in jac 0.34.9:

```
WARNING - [stable] binary prep failed: [Errno 8] Exec format error: '.../.pod-jac'
[ERROR] Deployment failed: manifest generation failed: Could not prepare the
        'stable' jac runtime ... (and JAC_NODE_ARCH for cross-arch nodes)
```

The deploy seals app bytecode by writing the **Linux pod binary** to `.pod-jac`
and executing it **on the host**
(`jaclang/scale/injector/bundle.jac::_precompile_app`). darwin cannot exec a
Linux binary, so it dies before any manifest is generated.

The error message points at `JAC_NODE_ARCH`, which is a red herring here: host
and node are both `arm64`. The mismatch is the OS, not the architecture. Nor is
it avoidable through config — `_precompile_app` runs unconditionally in
`pack_jab`, ahead of the `fat_bundle` check, and `BinaryInjector` subclasses
`PvcInjector` rather than being an alternative to it.

The data layer below is the one `jac start --scale` provisioned before it
failed, so MongoDB and Redis are exactly what the supported path creates.

## Deploy

```bash
# 1. Provision MongoDB and Redis (this part of --scale succeeds).
jac start --scale main.jac        # expect it to fail at "Preparing the ... runtime"

# 2. Build into minikube's own docker daemon so no registry is needed.
eval $(minikube docker-env)
docker build -f deploy/minikube/Dockerfile -t standup-app:local .

# 3. Deploy.
kubectl apply -f deploy/minikube/standup.yaml
kubectl rollout status deployment/standup-app

# 4. Reach it from the host. minikube's node IP is not routable from macOS
#    with the docker driver, so port-forward rather than using the NodePort.
kubectl port-forward svc/standup-app-service 8080:8000
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/healthz
```

Point the MCP server at it with `STANDUP_URL=http://localhost:8080`.

## Two traps worth knowing

**The base image sets `ENTRYPOINT ["jac"]`.** A `CMD ["jac", "start", ...]`
becomes `jac jac start ...`, and the pod crashloops with
`Not a valid file! Only supports .jac and .py`, which names neither `jac` nor
the real problem.

**`redis` is not in the base image, but `REDIS_URL` is in the pod.** The
runtime then logs `Redis connection failed: 'NoneType' object has no attribute
'from_url'` as a *warning* and carries on, but every OCC-guarded write
(`CreateTask`, `MoveTask`) fails with HTTP 500 `list index out of range`. Reads
keep working, so the app looks healthy until you try to write. `jac install
redis --no-save` in the Dockerfile fixes it.

## Scope

This is a verification harness, not a production deployment. It has no
ingress, no TLS, no resource limits, no horizontal scaling, and it bakes the
source into the image. Use `jac start --scale` from a Linux host for anything
real.
